defmodule FirehoseX.WebServer do
  @moduledoc """
  FirehoseX web server module.
  Starts the Cowboy web server and mounts FirehoseX.Router
  as the Plug router to handle incoming requests.
  """

  require Logger

  def start_link(port: port) do
    Logger.info "Starting FirehoseX.WebServer on port #{port}"
    {:ok, _} = Plug.Adapters.Cowboy.http(
      FirehoseX.Router,
      [],
      [port: port, ip: {127, 0, 0, 1}, acceptors: 250]
    )
  end
end
