defmodule FirehoseEx.Channel do
  @moduledoc """
  Firehose Channel related logic
  """

  require Logger

  @payload_delimiter "\n"

  def next_message(channel, last_sequence) do
    {:ok, [curr_seq, messages]} = FirehoseEx.Redis.pipeline([
      [:get, sequence_key(channel)],
      [:lrange, list_key(channel), 0, buffer_size]
    ])

    Logger.debug "Redis.pipeline(#{sequence_key(channel)}) returned: `#{curr_seq}` and `#{inspect messages}`"

    handle_next_message(channel, last_sequence, curr_seq |> parse_seq, messages)
  end

  def handle_next_message(channel, _, nil, _), do: subscribe(channel)

  def handle_next_message(channel, last_seq, curr_seq, _)
  when curr_seq - last_seq <= 0 do
    subscribe(channel)
  end

  def handle_next_message(channel, last_seq, curr_seq, messages) do
    diff = curr_seq - last_seq
    if diff < buffer_size do
      message = messages |> Enum.at(diff - 1)
      Logger.debug "Sending old message `#{message}` and sequence `#{curr_seq}` to client directly. Client is `#{diff}` behind, at `#{last_seq}`."
      {message, last_seq + 1}
    else
      [message | _] = messages
      Logger.debug "Sending latest message `#{message}` and sequence `#{curr_seq}` to client directly."
      {message, curr_seq}
    end
  end

  def parse_seq(nil), do: nil
  def parse_seq(val) when is_binary(val), do: val |> String.to_integer

  def subscribe(channel, opts \\ [timeout: :infinity]) do
    key = channel_updates_key(channel)
    FirehoseEx.Redis.subscribe(key, self)
    receive do
      {:redix_pubsub, :subscribe, ^key, nil} ->
        receive do
          {:redix_pubsub, :message, msg, ^key} ->
            [^channel, sequence, message] = msg |> String.split(@payload_delimiter)
            {message, sequence |> parse_seq}
          after opts[:timeout] ->
            Logger.info "Subscribe timed out for channel: #{channel} in pid: #{inspect self}"
        end
    end
  end

  def buffer_size do
    Application.get_env(:firehose_ex, :channel)[:buffer_size]
  end

  def channel_updates_key(channel) do
    FirehoseEx.Redis.key([channel, :channel_updates])
  end

  def sequence_key(channel) do
    FirehoseEx.Redis.key([channel, :sequence])
  end

  def list_key(channel) do
    FirehoseEx.Redis.key([channel, :list])
  end
end
