defmodule FirehoseEx.Subscription.Supervisor do
  use Supervisor
  require Logger

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    Logger.info "Starting Subscription Supervisor"

    children = [
      worker(FirehoseEx.Subscription.Manager, []),
    ]

    supervise(children, strategy: :one_for_one, restart: :permanent)
  end
end
