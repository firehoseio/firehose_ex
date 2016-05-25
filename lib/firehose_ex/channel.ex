defmodule FirehoseEx.Channel do
  defmodule Message do
    defstruct data: nil,
              sequence: 1
  end

  require Logger

  alias FirehoseEx.Channel
  alias FirehoseEx.Channel.Message

  defstruct name: nil,
            subscribers: [], # TODO: probably switch to ETS table
            messages: [],    # TODO: probably switch to ETS table
            buffer_size: nil,
            last_sequence: 0

  use GenServer

  # Public API functions

  def find(%Channel{name: name}) do
    find(name)
  end

  def find(channel_name) when is_binary(channel_name) do
    case :global.whereis_name({:channel, channel_name}) do
      :undefined ->
        channel = %Channel{name: channel_name}
        case FirehoseEx.Channel.Supervisor.start_channel(channel) do
          {:ok, pid} ->
            pid
          {:error, {:already_started, pid}} ->
            pid
        end
      pid ->
        pid
    end
  end

  def publish(channel, message, opts \\ []) do
    GenServer.call find(channel), {:publish, message, opts}
  end

  def subscribe(channel, opts \\ [timeout: :infinity]) do
    GenServer.call find(channel), {:subscribe, self}, opts[:timeout]
  end

  def set_buffer_size(channel, size) when size > 0 do
    GenServer.call find(channel), {:set_buffer_size, size}
  end

  def next_message(channel_name, last_sequence) when is_binary(channel_name) do
    next_message(%Channel{name: channel_name}, last_sequence)
  end

  def next_message(channel = %Channel{name: chan_name}, last_sequence) do
    case GenServer.call find(channel), {:messages_since, last_sequence} do
      [] ->
        subscribe(channel)
        receive do
          {:next_message, msg, ^chan_name} ->
            msg
        end
        messages ->
          messages |> Enum.reverse |> Enum.at(0)
    end
  end

  def default_buffer_size do
    Application.get_env(:firehose_ex, :channel)[:buffer_size]
  end

  def default_ttl do
    Application.get_env(:firehose_ex, :channel)[:buffer_ttl]
  end

  # GenServer callbacks

  def start_link(%FirehoseEx.Channel{} = channel) do
    channel = case channel.buffer_size do
      nil ->
        put_in channel.buffer_size, default_buffer_size
      _ ->
        channel
    end

    GenServer.start_link(__MODULE__, channel, name: {:global, {:channel, channel.name}})
  end

  def init(channel) do
    {:ok, channel}
  end

  def handle_call({:publish, message, opts}, _from, channel) do
    ttl = opts[:ttl] || default_ttl
    channel = _set_buffer_size(channel, opts[:buffer_size])

    Logger.debug "PUBLISH: #{inspect message} TO: #{channel.name}"
    channel = update_in channel.last_sequence, &(&1 + 1)
    message = %Message{data: message, sequence: channel.last_sequence}
    broadcast message, channel
    {:reply, :ok, channel |> add_message(message)}
  end

  def handle_call({:subscribe, pid}, from, channel) do
    Logger.debug "SUBCRIBE: #{inspect pid} TO: #{inspect channel}"
    {:reply, :ok, channel |> add_subscriber(pid)}
  end

  def handle_call({:set_buffer_size, size}, _, channel) do
    Logger.debug "SET BUFFER_SIZE: #{size} FOR: #{channel.name}"
    {:reply, :ok, _set_buffer_size(channel, size)}
  end

  def handle_call({:messages_since, last_sequence}, _, channel) do
    Logger.debug "#{channel.name} Messages since #{last_sequence}"
    message = Enum.take_while(channel.messages, &(&1.sequence > last_sequence))
    {:reply, message, channel}
  end

  # State internal helper functions

  defp broadcast(message, channel) do
    spawn_link fn ->
      channel.subscribers
      |> Enum.each(fn sub ->
        send sub, {:next_message, message, channel.name}
      end)
    end
  end

  defp add_message(channel, message) do
    update_in channel.messages, &(Enum.take([message | &1], channel.buffer_size))
  end

  defp add_subscriber(channel, sub) do
    update_in channel.subscribers, &[sub|&1]
  end

  defp _set_buffer_size(channel, size) when is_integer(size) and size > 0 do
    %{
      channel |
      buffer_size: size,
      messages: Enum.take(channel.messages, size)
    }
  end

  defp _set_buffer_size(channel, _), do: channel
end
