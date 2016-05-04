defmodule FirehoseEx.WebServer do
  @moduledoc """
  FirehoseEx web server module.
  Starts the Cowboy web server and mounts FirehoseEx.Router
  as the Plug router to handle incoming requests.
  """

  require Logger

  def start_link(port: port) do
    Logger.info "Starting FirehoseEx.WebServer on port #{port}"
    {:ok, _} = Plug.Adapters.Cowboy.http(
      FirehoseEx.Router,
      [],
      [port: port, ip: {0, 0, 0, 0}, acceptors: 250]
    )
  end
end
