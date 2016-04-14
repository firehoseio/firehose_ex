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
    |> send_resp(200, System.get_env("REVISION") || "")
  end

  get "/channels@firehose" do
    conn
    |> send_resp(200, "TODO")
  end

  match _ do
    conn = conn |> fetch_query_params
    channel = conn.request_path
    last_sequence = conn.params |> last_message_sequence

    if last_sequence < 0 do
      conn
      |> send_resp(400, "The last_message_sequence parameter may not be less than zero")
    else
      {msg, curr_seq} = FirehoseEx.Channel.next_message(channel, last_sequence)
      conn
      |> json_response(200, %{message: msg, last_sequence: curr_seq})
    end
  end

  def json_response(conn, status, data) do
    conn
    |> put_resp_content_type("text/json")
    |> send_resp(status, Poison.encode!(data))
  end

  defp last_message_sequence(%{last_message_sequence: val}) do
    val |> String.to_integer
  end

  defp last_message_sequence(_), do: 0
end
