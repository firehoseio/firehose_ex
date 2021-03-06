defmodule FirehoseEx.Redis do
  @moduledoc """
  Supervised Redis pool and helper functions for the Redis backend storage.
  """

  require Logger
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(redis_opts) do
    import Supervisor.Spec, warn: false

    pool_opts  = redis_opts[:pool]
    redis_opts = redis_opts |> Keyword.delete(:pool)

    children = [
      redis_pool(:redix_pool, Redix, pool_opts, redis_opts),
      redis_pool(:redix_pubsub_pool, Redix.PubSub, pool_opts, redis_opts),
      worker(FirehoseEx.Channel.Publisher, [])
    ]

    Logger.info "Starting FirehoseEx.Redis"
    Logger.info "Connecting to Redis: #{redis_opts[:host]}:#{redis_opts[:port]}"

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  def redis_pool(name, worker_module, pool_opts, redis_opts) do
    :poolboy.child_spec(
      name, [
        name: {:local, name},
        worker_module: worker_module,
        size: pool_opts[:pool_size],
        max_overflow: pool_opts[:max_overflow]
      ],
      redis_opts
    )
  end

  def command(cmd) do
    :poolboy.transaction(:redix_pool, &Redix.command(&1, cmd))
  end

  def pipeline(cmds) do
    :poolboy.transaction(:redix_pool, &Redix.pipeline(&1, cmds))
  end

  def subscribe(channels, recipient, opts \\ []) do
    :poolboy.transaction(
      :redix_pubsub_pool,
      &Redix.PubSub.subscribe(&1, channels, recipient, opts)
    )

    await_subscription_confimation(channels)
  end

  def await_subscription_confimation(channels) when is_list(channels) do
    channels |> Enum.each(&await_subscription_confimation/1)
    :ok
  end

  def await_subscription_confimation(channel) do
    receive do
      {:redix_pubsub, :subscribe, ^channel, nil} -> :ok
      # TODO: add timeout?
    end
  end

  def unsubscribe(channels, recipient, opts \\ []) do
    :poolboy.transaction(
      :redix_pubsub_pool,
      &Redix.PubSub.unsubscribe(&1, channels, recipient, opts)
    )
  end

  def key(segments) do
    "firehose:" <> Enum.join(segments, ":")
  end
end
