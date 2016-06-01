defmodule FirehoseX.Channel.Supervisor do
  require Logger
  use Supervisor

  @supervisor_name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: @supervisor_name)
  end

  def start_channel(%FirehoseX.Channel{} = channel) do
    Supervisor.start_child(@supervisor_name, [channel])
  end

  def init(:ok) do
    import Supervisor.Spec, warn: false

    children = [
      worker(FirehoseX.Channel, [], restart: :transient)
    ]

    Logger.info "Starting FirehoseX.Channel.Supervisor"

    supervise(children, strategy: :simple_one_for_one, name: @supervisor_name)
  end
end
