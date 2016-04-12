defmodule FirehoseEx do
  @moduledoc """
  FirehoseEx is a rewrite of PollEverywhere's Firehose in Elixir & Erlang/OTP.
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(FirehoseEx.WebServer, [Application.get_env(:firehose_ex, :web)]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FirehoseEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
