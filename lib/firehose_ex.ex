defmodule FirehoseEx do
  @moduledoc """
  FirehoseEx is a rewrite of PollEverywhere's Firehose in Elixir & Erlang/OTP.
  """

  use Application
  import Supervisor.Spec, warn: false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, args) do
    args = Keyword.merge([web_server: true], args)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FirehoseEx.Supervisor]
    Supervisor.start_link(children(args), opts)
  end

  def children(web_server: true), do: [
    worker(FirehoseEx.WebServer, [web_conf]) | default_children
  ]

  def children(_), do: default_children

  def default_children, do: [
    supervisor(FirehoseEx.Channel.Supervisor, [])
  ]

  @version Mix.Project.config[:version]
  def version do
    @version
  end

  def web_conf do
    conf = Application.get_env(:firehose_ex, :web)
    case System.get_env "PORT" do
      nil -> conf
      p   -> conf |> Keyword.merge(port: p |> String.to_integer)
    end
  end
end
