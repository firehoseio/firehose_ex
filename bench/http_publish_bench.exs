defmodule HttpPublishBenchmark do
  use Benchfella

  setup_all do
    HTTPotion.start
    counter = Agent.start(fn -> 0 end, name: :request_counter)
    collector = spawn(__MODULE__, :response_collector, [0])
    Process.register(collector, :response_collector)

    {:ok, [collector: collector, collector: collector]}
  end

  teardown_all [counter: counter, collector: coll] do
    if coll != nil do
      send coll, {:awaiting_results, self}
      receive do
        {:collected, count} ->
          IO.puts "Received #{count} results"
        after 1000 ->
          send coll, {:get_results, self}
          receive do
            {:collected, count} ->
              IO.puts "Received #{counter_val} results"
            after 1000 ->
              IO.puts "Error: timeout after 5 secs"
          end
      end
    end

    Process.exit(counter, :kill)
    Process.exit(coll, :kill)
  end


  def response_collector(count, parent \\ nil) do
    receive do
      {:awaiting_results, parent} ->
        if count == counter_val do
          send parent, {:collected, count}
        else
          response_collector count, parent
        end
      {:get_results, parent} ->
        send parent, {:collected, count}
      # only count AsyncEnd messages to count correct number of http request
      # responses
      %HTTPotion.AsyncEnd{} ->
        count = count + 1
        if count >= counter_val && parent != nil do
          send parent, {:collected, count}
        else
          response_collector count, parent
        end
      _ ->
        response_collector count, parent
    end
  end

  def uri(channel) do
    "http://localhost:7474/#{channel}"
  end

  def publish(channel, counter) do
    try do
      result = HTTPotion.put uri(channel), [body: "{'hello': 'world', 'counter': #{counter}}", headers: ["content-type": "application/json"]]
      Agent.update(:request_counter, &(&1 + 1))
      result
    rescue
      e in HTTPotion.HTTPError ->
        publish(channel, counter)
    end
  end

  def multi_publish(1, channel) do
    publish(channel, counter_val)
    :ok
  end

  def multi_publish(n, channel) when n > 1 do
    publish(channel, counter_val)
    multi_publish(n - 1, channel)
  end

  def async_get(channel) do
    try do
      HTTPotion.get(
        uri(channel) <> "?last_message_sequence=#{counter_val}",
        headers: ["content-type": "application/json"],
        stream_to: Process.whereis(:response_collector)
      )
    rescue
      e in HTTPotion.HTTPError ->
        async_get(channel)
    end
    :ok
  end

  def async_multi_get(1, channel) do
    async_get(channel)
    :ok
  end

  def async_multi_get(amount, channel) when amount > 1 do
    async_get(channel)
    async_multi_get(amount - 1, channel)
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

  def get(channel) do
    HTTPotion.get(
      uri(channel) <> "?last_message_sequence=#{counter_val}",
      headers: ["content-type": "application/json"]
    )
  end

  def counter_val do
    Agent.get(:request_counter, &(&1))
  end

  def multi_publish_get(publish, get, channel) do
    t1 = Task.async fn ->
      multi_publish(publish, channel)
    end
    t2 = Task.async fn ->
      async_multi_get(get, channel)
    end
    Task.await(t1)
    Task.await(t2)
  end

  bench "http-p010r010", do: multi_publish_get(10, 10, "test/channel")
  bench "http-p050r025", do: multi_publish_get(50, 25, "test/channel")
  bench "http-p050r050", do: multi_publish_get(50, 50, "test/channel")
  bench "http-p100r100", do: multi_publish_get(100, 100, "test/channel")
  bench "http-p200r100", do: multi_publish_get(200, 100, "test/channel")
  bench "http-p200r200", do: multi_publish_get(200, 200, "test/channel")
  bench "http-p500r200", do: multi_publish_get(500, 200, "test/channel")
  bench "http-p500r500", do: multi_publish_get(500, 500, "test/channel")

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
