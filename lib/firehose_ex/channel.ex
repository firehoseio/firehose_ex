defmodule FirehoseEx.Channel do
  @moduledoc """
  Firehose Channel related logic
  """

  require Logger
  alias FirehoseEx.Redis

  def publish(channel, message, opts \\ []) do
    ttl = opts[:ttl] || default_ttl
    buf_size = opts[:buffer_size] || buffer_size

    FirehoseEx.Channel.Publisher.eval_publish_script(channel, message, ttl, buf_size)
  end

  def next_message(channel, last_sequence) do
    {:ok, [curr_seq, messages]} = Redis.pipeline([
      [:get, sequence_key(channel)],
      [:lrange, list_key(channel), 0, buffer_size]
    ])

    Logger.debug "pipeline returned: `#{curr_seq}` and `#{inspect messages}`"

    handle_next_message(channel, last_sequence, curr_seq |> parse_seq, messages)
  end

  # Either this resource has never been seen before or we are all caught up.
  # Subscribe and hope something gets published to this end-point.
  def handle_next_message(channel, _, nil, _), do: subscribe(channel)
  def handle_next_message(channel, last_seq, curr_seq, _)
  when curr_seq - last_seq <= 0
  do
    subscribe(channel)
  end

  def handle_next_message(_channel, last_seq, curr_seq, messages) do
    diff = curr_seq - last_seq
    if diff < buffer_size do
      # The client is kinda-sorta running behind, but has a chance to catch
      # up. Catch them up FTW.
      # But we won't "catch them up" if last_sequence was zero/nil because
      # that implies the client is connecting for the 1st time.
      message = messages |> Enum.at(diff - 1)
      Logger.debug "Sending old message `#{message}` and sequence `#{curr_seq}` to client directly. Client is `#{diff}` behind, at `#{last_seq}`."
      {message, last_seq + 1}
    else
      # The client is hopelessly behind and underwater. Just reset
      # their whole world with the latest message.
      [message | _] = messages
      Logger.debug "Sending latest message `#{message}` and sequence `#{curr_seq}` to client directly."
      {message, curr_seq}
    end
  end

  def parse_seq(nil), do: nil
  def parse_seq(val) when is_binary(val), do: val |> String.to_integer

  def subscribe(channel, opts \\ [timeout: :infinity]) do
    key = updates_key(channel)
    :ok = Redis.subscribe(key, self)
    receive do
      {:redix_pubsub, :message, msg, ^key} ->
        {_channel, msg, curr_seq} = msg |> FirehoseEx.Channel.Publisher.from_payload
        {msg, curr_seq}
      after opts[:timeout] ->
        Logger.info "Subscribe timed out for channel: #{channel} in pid: #{inspect self}"
    end
  end

  def buffer_size do
    Application.get_env(:firehose_ex, :channel)[:buffer_size]
  end

  def default_ttl do
    Application.get_env(:firehose_ex, :channel)[:buffer_ttl]
  end

  def updates_key(channel) do
    Redis.key([channel, :channel_updates])
  end

  def sequence_key(channel) do
    Redis.key([channel, :sequence])
  end

  def list_key(channel) do
    Redis.key([channel, :list])
  end
end
