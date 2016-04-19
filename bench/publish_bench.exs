defmodule PublishBenchmark do
  use Benchfella
  alias FirehoseEx.Channel

  setup_all do
    {:ok, _pid} = FirehoseEx.start(nil, web_server: false)
    counter = Agent.start(fn -> 0 end, name: :request_counter)
    IO.puts "Counter: #{counter_val}"
    {:ok, [counter: counter]}
  end

  teardown_all _ do
    IO.puts "Counter: #{counter_val}"
  end

  def uri(channel) do
    "http://localhost:7474/#{channel}"
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

  bench "p001" do
    publish("test/channel", counter_val)
    :ok
  end

  bench "p005" do
    multi_publish(5, "test/channel")
  end

  bench "p010" do
    multi_publish(10, "test/channel")
  end

  bench "p050" do
    multi_publish(50, "test/channel")
  end

  bench "p100" do
    multi_publish(100, "test/channel")
  end

  bench "p100" do
    multi_publish(100, "test/channel")
  end

  bench "p200" do
    multi_publish(200, "test/channel")
  end

  bench "p300" do
    multi_publish(300, "test/channel")
  end

  bench "p400" do
    multi_publish(400, "test/channel")
  end

  bench "p500" do
    multi_publish(500, "test/channel")
  end
end
