defmodule PublishBenchmark do
  use Benchfella
  alias FirehoseX.Channel

  setup_all do
    {:ok, _pid} = FirehoseX.start(nil, web_server: false)
    {:ok, counter} = Agent.start(fn -> 0 end, name: :request_counter)
    IO.puts "Counter: #{counter_val}"
    {:ok, [counter: counter]}
  end

  teardown_all [counter: counter] do
    IO.puts "Counter: #{counter_val}"
    Process.exit(counter, :kill)
  end

  def publish(channel, counter) do
    msg = "{'hello': 'world', 'counter': #{counter}}"
    Agent.update(:request_counter, &(&1 + 1))
    Channel.publish(channel, msg)
  end

  def multi_publish(1, channel) do
    publish(channel, counter_val)
    :ok
  end

  def multi_publish(n, channel) when n > 1 do
    publish(channel, counter_val)
    multi_publish(n - 1, channel)
  end

  def counter_val do
    Agent.get(:request_counter, &(&1))
  end

  bench "p001", do: multi_publish(1, "test/channel")
  bench "p005", do: multi_publish(5, "test/channel")
  bench "p010", do: multi_publish(10, "test/channel")
  bench "p050", do: multi_publish(50, "test/channel")
  bench "p100", do: multi_publish(100, "test/channel")
  bench "p100", do: multi_publish(100, "test/channel")
  bench "p200", do: multi_publish(200, "test/channel")
  bench "p300", do: multi_publish(300, "test/channel")
  bench "p400", do: multi_publish(400, "test/channel")
  bench "p500", do: multi_publish(500, "test/channel")
end
