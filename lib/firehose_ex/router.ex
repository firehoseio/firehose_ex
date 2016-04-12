defmodule FirehoseEx.Router do
  @moduledoc """
  Basic HTTP Router module for FirehoseEx.
  """

  require Logger
  use Plug.Router

  def init(_) do
    Logger.info "Starting FirehoseEx.Router"
  end

  if Mix.env == :dev do
    use Plug.Debugger, otp_app: :firehose_ex
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  # routes

  get "/revision" do
    conn
    |> send_resp(200, System.get_env("REVISION"))
  end
end
