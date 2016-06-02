defmodule HttpPublishBenchmark do
  use Benchfella
  require Logger

  setup_all do
    HTTPotion.start
    {:ok, global_counter} = Agent.start(fn -> 0 end, name: :global_counter)
    {:ok, [global_counter: global_counter]}
  end

  def teardown_all([global_counter: gc]) do
    total_count = Agent.get(:global_counter, &(&1))
    Logger.info "Published a total of #{total_count} messages."
  end

  def setup(publish_amount, get_amount) do
    {:ok, publish_counter} = Agent.start(fn -> 0 end)
    collector = spawn_link(__MODULE__, :response_collector, [0, get_amount])
    # Process.register(collector, :response_collector)
    {publish_counter, collector}
  end

  def teardown({counter, coll}) do
    if coll != nil do
      send coll, {:awaiting_results, self}
      receive do
        {:collected, count} ->
          Agent.update(:global_counter, &(&1 + count))
          Logger.info "TEARDOWN #{inspect counter} #{inspect coll} | Received #{count} results"
        after 1000 ->
          send coll, {:get_results, self}
          receive do
            {:collected, count} ->
              Agent.update(:global_counter, &(&1 + count))
              Logger.info "TEARDOWN #{inspect counter} #{inspect coll} | Received #{count} results"
            after 5000 ->
              Logger.error "TEARDOWN | Timeout after 5 secs"
          end
      end
    end

    true = Process.exit(counter, :kill)
    true = Process.exit(coll, :kill)
  end

  def response_collector(count, get_amount, parent \\ nil) do
    receive do
      {:awaiting_results, parent} ->
        if count == get_amount do
          send parent, {:collected, count}
        else
          response_collector count, get_amount, parent
        end
      {:get_results, parent} ->
        send parent, {:collected, count}
      # only count AsyncEnd messages to count correct number of http request
      # responses
      %HTTPotion.AsyncEnd{} ->
        count = count + 1
        if count >= get_amount && parent != nil do
          send parent, {:collected, count}
        else
          response_collector count, get_amount, parent
        end
      %HTTPotion.AsyncHeaders{} ->
        response_collector count, get_amount, parent
      %HTTPotion.AsyncChunk{} ->
        response_collector count, get_amount, parent
      msg ->
        Logger.error "COLLECTOR | Unexpected message: #{inspect msg}"
    end
  end

  def uri(channel) do
    "http://localhost:7474/#{channel}"
  end

  def publish(channel, publish_counter) do
    try do
      counter = counter_val(publish_counter)
      # IO.puts "pub #{counter} @ #{channel}"
      result = HTTPotion.put uri(channel), [body: "{'hello': 'world', 'counter': #{counter}}", headers: ["content-type": "application/json"]]
      Agent.update(publish_counter, &(&1 + 1))
      result
    rescue
      err in HTTPotion.HTTPError ->
        Agent.update(publish_counter, &(&1 - 1))
        case err.message do
          "retry_later" ->
            Logger.debug "PUBLISH | Retry later, wait 10ms"
            receive do
              after 10 ->
                publish(channel, publish_counter)
            end
          "econnrefused" ->
            Logger.error "PUBLISH | Connection refused, stopping"
            raise err
          _ ->
            Logger.error "PUBLISH | #{inspect(err)}"
            publish(channel, publish_counter)
        end
    end
  end

  def multi_publish(1, channel, publish_counter) do
    publish(channel, publish_counter)
    :ok
  end

  def multi_publish(n, channel, publish_counter) when n > 1 do
    publish(channel, publish_counter)
    # receive do
    #   after :random.uniform(25) ->
        multi_publish(n - 1, channel, publish_counter)
    # end
  end

  def async_get(channel, sequence, collector) do
    try do
      HTTPotion.get(
        uri(channel) <> "?last_message_sequence=#{sequence}",
        headers: ["content-type": "application/json"],
        stream_to: collector
      )
    rescue
      _ in HTTPotion.HTTPError ->
        async_get(channel, sequence, collector)
    end
    :ok
  end

  def async_multi_get(1, channel, publish_counter, collector) do
    async_get(channel, counter_val(publish_counter), collector)
    :ok
  end

  def async_multi_get(amount, channel, publish_counter, collector) when amount > 1 do
    async_get(channel, counter_val(publish_counter), collector)
    async_multi_get(amount - 1, channel, publish_counter, collector)
  end

  def await_async_multi(amount, fun) do
    (1..amount)
    |> Enum.map(fn i ->
      Task.async(fn ->
        fun.(i)
      end)
    end)
    |> Enum.map(&Task.await(&1, 10000))
  end

  def get(channel, counter_pid) do
    HTTPotion.get(
      uri(channel) <> "?last_message_sequence=#{counter_val(counter_pid)}",
      headers: ["content-type": "application/json"]
    )
  end

  def counter_val(nil), do: raise("counter_pid is nil!")
  def counter_val(counter_pid) do
    Agent.get(counter_pid, &(&1))
  end

  def multi_publish_get(publish_amount, get_amount, channel) do
    setup_data = {publish_counter, collector} = setup(publish_amount, get_amount)

    # Channel.find(channel) # make sure chan process is started
    t1 = Task.async fn ->
      Logger.info "Publishing #{publish_amount} messages to #{channel}"
      multi_publish(publish_amount, channel, publish_counter)
    end
    t2 = Task.async fn ->
      async_multi_get(get_amount, channel, publish_counter, collector)
    end
    Task.await(t1, 10000)
    Task.await(t2, 10000)

    teardown(setup_data)
  end

  def random_channel do
    :random.seed(:erlang.timestamp)
    "test/channel/#{:random.uniform(1_000_000)}"
  end

  # bench "http-p010r010", do: multi_publish_get(10, 10,   random_channel)
  # bench "http-p050r025", do: multi_publish_get(50, 25,   random_channel)
  # bench "http-p050r050", do: multi_publish_get(50, 50,   random_channel)
  # bench "http-p100r100", do: multi_publish_get(100, 100, random_channel)
  # bench "http-p200r100", do: multi_publish_get(200, 100, random_channel)
  # bench "http-p200r200", do: multi_publish_get(200, 200, random_channel)
  # bench "http-p500r200", do: multi_publish_get(500, 200, random_channel)
  # bench "http-p500r500", do: multi_publish_get(500, 500, random_channel)

  bench "http-p010r010", do: multi_publish_get(10, 10,   "test/channel")
  bench "http-p050r025", do: multi_publish_get(50, 25,   "test/channel")
  bench "http-p050r050", do: multi_publish_get(50, 50,   "test/channel")
  bench "http-p100r100", do: multi_publish_get(100, 100, "test/channel")
  bench "http-p200r100", do: multi_publish_get(200, 100, "test/channel")
  bench "http-p200r200", do: multi_publish_get(200, 200, "test/channel")
  bench "http-p500r200", do: multi_publish_get(500, 200, "test/channel")
  bench "http-p500r500", do: multi_publish_get(500, 500, "test/channel")
  bench "http-p10r500",  do: multi_publish_get(10, 500,  "test/channel")
  bench "http-p20r1000", do: multi_publish_get(20, 1000, "test/channel")

  # bench "http-2-p10r025" do
  #   await_async_multi 2, fn i ->
  #     multi_publish(10, "test/channel/#{i}")
  #     async_multi_get(25, "test/channel/#{i}")
  #   end
  # end
  #
  # bench "http-5-p050r025" do
  #   await_async_multi 5, fn i ->
  #     multi_publish(50, "test/channel/#{i}")
  #     async_multi_get(25, "test/channel/#{i}")
  #   end
  # end

  # # sync versions
  #
  # bench "s-http-p1r1" do
  #   publish("test/channel", counter_val)
  #   get("test/channel")
  #   :ok
  # end
  #
  # bench "s-http-p1r2" do
  #   publish("test/channel", counter_val)
  #   async_get("test/channel")
  #   get("test/channel")
  #   :ok
  # end
  #
  # bench "s-http-p2r1" do
  #   publish("test/channel", counter_val)
  #   publish("test/channel", counter_val)
  #   get("test/channel")
  #   :ok
  # end
  #
  # bench "s-http-p2r2" do
  #   publish("test/channel", counter_val)
  #   publish("test/channel", counter_val)
  #   get("test/channel")
  #   get("test/channel")
  #   :ok
  # end
end
