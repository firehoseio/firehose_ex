defmodule FirehoseEx.Redis do
  @moduledoc """
  Supervised Redis pool and helper functions for the Redis backend storage.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(redis_opts) do
    pool_opts = [
      name: {:local, :redix_pool},
      worker_module: Redix,
      size: redis_opts[:pool][:pool_size],
      max_overflow: redis_opts[:pool][:max_overflow]
    ]

    redis_opts = redis_opts |> Keyword.delete(:pool)

    children = [
      :poolboy.child_spec(:redix_pool, pool_opts, redis_opts)
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(cmd) do
    :poolboy.transaction(:redix_pool, &Redix.command(&1, cmd))
  end

  def pipeline(cmds) do
    :poolboy.transaction(:redix_pool, &Redix.pipeline(&1, cmds))
  end

  def key(segments) do
    "firehose:" <> Enum.join(segments, ":")
  end
end
