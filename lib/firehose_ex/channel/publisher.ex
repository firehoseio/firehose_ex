defmodule FirehoseEx.Channel.Publisher do
  @moduledoc """
  This module implements a Agent that keeps track of the publish script digest
  value returned by Redis when registering the lua publish script.
  Automatically re-registers it, if needed (i.e. when Redis restarted or scripts
  were flushed).
  Also implements logic for evaluating the lua publish script in Redis.
  """

  require Logger
  alias FirehoseEx.Redis

  def start_link do
    Logger.info "Starting FirehoseEx.Channel.Publisher Agent"
    # default to nil as initial value
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def eval_publish_script(channel, message, ttl, buffer_size) do
    import FirehoseEx.Channel, only: [sequence_key: 1, list_key: 1, updates_key: 1]

    script_args = [
      sequence_key(channel),
      list_key(channel),
      updates_key(channel),
      ttl,
      message,
      buffer_size,
      @payload_delimiter,
      channel
    ]

    cmd = [:evalsha, script_digest, script_args |> Enum.count] ++ script_args
    case Redis.command(cmd) do
      {:ok, sequence} = result ->
        Logger.debug "Redis stored/published `#{message}` to list `#{list_key(channel)}` with sequence `#{sequence}`"
        result
      {:error, %Redix.Error{message: "NOSCRIPT No matching script. Please use EVAL."}} ->
        # Handle missing Lua publishing script in cache
        # (such as Redis restarting or someone executing SCRIPT FLUSH)
        register_script!
        eval_publish_script(channel, message, ttl, buffer_size)
    end
  end

  def script_digest do
    Agent.get_and_update(__MODULE__, fn
      nil ->
        digest = register_publish_script
        {digest, digest}
      digest ->
        {digest, digest}
    end)
  end

  def register_script! do
    Agent.update(__MODULE__, fn _ -> register_publish_script end)
  end

  @redis_publish_script """
  local sequence_key      = KEYS[1]
  local list_key          = KEYS[2]
  local channel_key       = KEYS[3]
  local ttl               = KEYS[4]
  local message           = KEYS[5]
  local buffer_size       = KEYS[6]
  local payload_delimiter = KEYS[7]
  local firehose_resource = KEYS[8]

  local current_sequence = redis.call('get', sequence_key)
  if current_sequence == nil or current_sequence == false then
    current_sequence = 0
  end

  local sequence = current_sequence + 1
  local message_payload = firehose_resource .. payload_delimiter .. sequence .. payload_delimiter .. message

  redis.call('set', sequence_key, sequence)
  redis.call('expire', sequence_key, ttl)
  redis.call('lpush', list_key, message)
  redis.call('ltrim', list_key, 0, buffer_size - 1)
  redis.call('expire', list_key, ttl)
  redis.call('publish', channel_key, message_payload)

  return sequence
  """

  defp register_publish_script do
    {:ok, digest} = Redis.command [:script, :load, @redis_publish_script]
    Logger.info "Registered Lua publishing script with Redis => #{digest}"
    digest
  end
end
