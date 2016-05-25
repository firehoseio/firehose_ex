defmodule FirehoseEx.Channel.Test do
  use ExUnit.Case
  use TestHelper

  doctest FirehoseEx.Channel
  alias FirehoseEx.Channel

  def publish(chan, messages) do
    spawn fn ->
      messages
      |> Enum.each(&Channel.publish(chan, &1))
    end
  end

  def expect_message(chan, message, sequence, timeout \\ 1000) do
    receive do
      {
        :next_message,
        %Channel.Message{data: ^message, sequence: ^sequence},
        chan_name
      } ->
        assert chan_name == chan.name
      msg ->
        assert false
      after timeout ->
        assert false
    end
  end

  setup do
    :random.seed(:erlang.timestamp)
    {:ok, %{
      channel: %Channel{name: "/test_channel/#{:random.uniform(1_000_000)}"}
    }}
  end

  test "Channel.find", %{channel: chan} do
    assert pid = Channel.find(chan)
    assert is_pid(pid)
    assert ^pid = Channel.find(chan)
  end

  test "Channel.start_link", %{channel: chan} do
    {:ok, pid} = Channel.start_link(chan)
    assert Channel.find(chan.name) == pid
  end

  test "Channel.publish", %{channel: chan} do
    assert :ok = Channel.subscribe(chan)
    assert :ok = Channel.publish(chan, "woot")
    assert :ok = Channel.publish(chan, "woot")

    expect_message chan, "woot", 1
  end

  test "Channel.set_buffer_size", %{channel: chan} do
    assert :ok = Channel.set_buffer_size(chan, 100)
    assert :ok = Channel.set_buffer_size(chan, 10)
    assert :ok = Channel.set_buffer_size(chan, 1)

    assert :ok = Channel.publish(chan, "a")
    assert :ok = Channel.publish(chan, "b")
    assert %Channel.Message{data: "b", sequence: 2} = Channel.next_message(chan, 0)

    assert :ok = Channel.set_buffer_size(chan, 2)
    assert :ok = Channel.publish(chan, "c")
    assert :ok = Channel.publish(chan, "d")
    assert :ok = Channel.publish(chan, "e")

    msg1 = %Channel.Message{data: "d", sequence: 4}
    msg2 = %Channel.Message{data: "e", sequence: 5}

    assert msg1 == Channel.next_message(chan, 1)
    assert msg1 == Channel.next_message(chan, 2)
    assert msg1 == Channel.next_message(chan, 3)

    assert msg2 == Channel.next_message(chan, 4)
  end

  test "Channel.subscribe", %{channel: chan} do
    messages = ["{'test': 'message1'}", "{'test': 'message2'}"]
    publish(chan, messages)
    :timer.sleep(100)
    assert %FirehoseEx.Channel.Message{data: "{'test': 'message1'}", sequence: 1} = Channel.next_message(chan, 0)
    assert %FirehoseEx.Channel.Message{data: "{'test': 'message2'}", sequence: 2} = Channel.next_message(chan, 1)
  end
end
