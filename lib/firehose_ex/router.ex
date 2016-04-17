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

  put _ do
    {:ok, body, conn} = conn |> read_body
    channel = conn.request_path
    ttl     = cache_control(conn)["max-age"]

    Logger.debug "HTTP published #{body} to #{channel} with ttl #{inspect ttl}"

    opts = [ttl: ttl] |> Keyword.merge(
      case conn |> get_req_header("HTTP_X_FIREHOSE_BUFFER_SIZE") do
        [] -> []
        [bs]  -> [buffer_size: bs |> String.to_integer]
      end
    )

    {:ok, sequence} = FirehoseEx.Channel.publish(channel, body, opts)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(202, "")
  end

  get _ do
    conn = conn |> fetch_query_params
    last_sequence = conn.params |> last_message_sequence

    if last_sequence < 0 do
      conn
      |> send_resp(400, "The last_message_sequence parameter may not be less than zero")
    else
      {msg, curr_seq} = FirehoseEx.Channel.next_message(conn.request_path, last_sequence)
      conn
      |> json_response(200, %{message: msg, last_sequence: curr_seq})
    end
  end

  match _ do
    Logger.debug "HTTP #{conn.method} not supported"
    conn
    |> put_resp_header("Allow", "GET")
    |> send_resp(405, "#{conn.method} not supported.")
  end

  defp json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Poison.encode!(data))
  end

  defp last_message_sequence(%{"last_message_sequence" => val}) do
    val |> String.to_integer
  end

  defp last_message_sequence(_), do: 0

  def cache_control(conn) do
    case conn |> get_req_header("HTTP_CACHE_CONTROL") do
      [] -> %{}
      [val] ->
        val
        |> String.split(",")
        |> Enum.map(fn directive ->
          [key, val] = directive |> String.split("=")
          {key |> String.downcase, val}
        end)
        |> Enum.into(%{})
    end
  end
end
