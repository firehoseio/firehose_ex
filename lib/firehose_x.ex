defmodule FirehoseX do
  @moduledoc """
  FirehoseX is a rewrite of PollEverywhere's Firehose in Elixir & Erlang/OTP.
  """

  use Application
  import Supervisor.Spec, warn: false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, args) do
    connect_to_cluster

    args = Keyword.merge([web_server: true], args)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FirehoseX.Supervisor]
    Supervisor.start_link(children(args), opts)
  end

  def children(web_server: true), do: [
    worker(FirehoseX.WebServer, [web_conf]) | default_children
  ]

  def children(_), do: default_children

  def default_children, do: [
    supervisor(FirehoseX.Channel.Supervisor, [])
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

  def connect_to_cluster do
    nodes
    |> Enum.each(&connect_to_node/1)
  end

  def connect_to_node(node) do
    require Logger
    Logger.info "Connecting to node #{node}"
    Node.connect(node)
  end

  def nodes do
    config_nodes = Application.get_env(:firehose_ex, :nodes) || []
    [Node.self | config_nodes]
  end
end
