defmodule FirehoseEx.RedisChannel.Test do
  use ExUnit.Case
  use TestHelper

  doctest FirehoseEx.RedisChannel
  alias FirehoseEx.RedisChannel, as: Channel

  def publish(chan, messages) do
    spawn fn ->
      messages
      |> Enum.each(&Channel.publish(chan, &1))
    end
  end

  setup do
    :random.seed(:erlang.timestamp)
    {:ok, %{channel: "/test_channel/#{:random.uniform(1_000_000)}"}}
  end

  test "redis key helper functions", %{channel: chan} do
    assert Channel.list_key(chan) == "firehose:#{chan}:list"
    assert Channel.sequence_key(chan) == "firehose:#{chan}:sequence"
  end

  test "Channel.subscribe", %{channel: chan} do
    messages = ["{'test': 'message1'}", "{'test': 'message2'}"]
    publish(chan, messages)
    assert {"{'test': 'message1'}", 1} = Channel.subscribe(chan, timeout: 50)
    assert {"{'test': 'message2'}", 2} = Channel.subscribe(chan, timeout: 50)
    assert :timeout = Channel.subscribe(chan, timeout: 50)
  end
end
