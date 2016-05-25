defmodule FirehoseEx.Channel.Supervisor do
  require Logger
  use Supervisor

  @supervisor_name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_channel(%FirehoseEx.Channel{} = channel) do
    Supervisor.start_child(@supervisor_name, [channel])
  end

  def init(:ok) do
    import Supervisor.Spec, warn: false

    children = [
      worker(FirehoseEx.Channel, [], restart: :transient)
    ]

    Logger.info "Starting FirehoseEx.Channel.Supervisor"

    supervise(children, strategy: :simple_one_for_one, name: @supervisor_name)
  end
end
