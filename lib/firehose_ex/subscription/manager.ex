defmodule FirehoseEx.Subscription.Manager do
  require Logger
  use GenServer
  alias FirehoseEx.Redis

  defmodule State do
    defstruct subscriptions: %{},
              refs_to_sub: %{}
  end

  alias FirehoseEx.Subscription
  alias FirehoseEx.Message
  alias Subscription.Manager.State

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @updates_key FirehoseEx.Channel.channel_updates_key

  def init(opts \\ []) do
    Logger.info "Starting Subscription Manager"
    :ok = Redis.subscribe(@updates_key, __MODULE__)
    {:ok, %State{}}
  end

  def subscribe(subscription) do
    GenServer.cast __MODULE__, {:subscribe, subscription}
  end

  def unsubscribe(subscription) do
    GenServer.cast __MODULE__, {:unsubscribe, subscription}
  end

  def broadcast(message) do
    GenServer.cast __MODULE__, {:broadcast, message}
  end

  def handle_cast({:subscribe, subscription = %Subscription{}}, state) do
    {:noreply, state |> add_subscription(subscription)}
  end

  def handle_cast({:unsubscribe, subscription = %Subscription{}}, state) do
    {:noreply, state |> remove_subscription(subscription)}
  end

  def handle_cast({:broadcast, message}, state) do
    broadcast_message(state, message)
    {:noreply, state}
  end

  def handle_info({:redix_pubsub, :message, msg, @updates_key}, state) do
    broadcast FirehoseEx.Channel.Publisher.message_from_payload(msg)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    Logger.debug "Subscriber process down: #{inspect pid}"
    case state.refs_to_sub[ref] do
      nil ->
        Logger.debug "No subscription found for monitor ref: #{inspect ref}"
        {:noreply, state}
      sub ->
        Logger.debug "Subscription found: #{inspect sub} for monitor ref: #{inspect ref}"
        {:noreply, remove_subscription(state, sub)}
    end
  end

  def handle_info(msg, state) do
    Logger.info "Subscription Manager | Unknown message: #{inspect msg} | state: #{inspect state}"
    {:noreply, state}
  end

  defp add_subscription(state, sub) do
    Logger.debug "Subscribe #{sub.channel} #{inspect sub.subscriber}"
    ref = Process.monitor(sub.subscriber)
    sub = %{sub | monitor_ref: ref}
    state = update_in state.subscriptions[sub.channel], fn
      nil  -> [sub]
      subs -> [sub | subs]
    end
    put_in state.refs_to_sub[ref], sub
  end

  defp remove_subscription(state, sub) do
    Logger.debug "Unsubscribe #{sub.channel} #{inspect sub.subscriber}"
    state = update_in state.subscriptions[sub.channel], fn subs ->
      Enum.reject(subs, &(&1.subscriber == sub.subscriber))
    end
    case sub.monitor_ref do
      nil -> state
      ref -> update_in state.refs_to_sub, &Map.delete(&1, ref)
    end
  end

  defp broadcast_message(state, message) do
    subs = state
           |> subscribers(message)

    Enum.each(subs, fn (s) ->
      send_to_subscriber(s, message)
    end)
  end

  defp subscribers(state, %Message{channel: channel}) do
    state.subscriptions
    |> Map.get(channel, [])
  end

  defp send_to_subscriber(sub, message) do
    if message.sequence > sub.last_sequence do
      Logger.debug "Sending message in #{message.channel} to subscriber #{inspect sub.subscriber}"
      send sub.subscriber, message
    end
  end
end
