defmodule GameWeb.InsiderLive do
  use GameWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    Phoenix.View.render(GameWeb.InsiderView, "insider.html", assigns)
  end

  @impl true
  def mount(_params, %{"id" => id, "game_ref" => game_ref, "me" => me}, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(Game.PubSub, "insider:"<>id)
      {:ok, pub_state} = Game.Manager.get_pub_state(game_ref)
      {:ok, priv_state} = Game.Manager.get_priv_state(game_ref, me)
      socket = socket
        |> assign(lobby_id: id)
        |> assign(game_ref: game_ref)
        |> assign(me: me)
        |> assign(pub_state: pub_state)
        |> assign(priv_state: priv_state)
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("start_guessing", _value, socket) do
    :ok = Game.Manager.start_guessing(socket.assigns.game_ref)
    {:noreply, socket}
  end

  @impl true
  def handle_event("word_not_found", _value, socket) do
    :ok = Game.Manager.word_not_found(socket.assigns.game_ref)
    {:noreply, socket}
  end

  @impl true
  def handle_event("word_found", %{"player" => player}, socket) do
    :ok = Game.Manager.word_found(socket.assigns.game_ref, player)
    {:noreply, socket}
  end

  @impl true
  def handle_event("judge", %{"vote" => "yay"}, socket) do
    :ok = Game.Manager.judge(socket.assigns.game_ref, socket.assigns.me, true)
    {:noreply, assign(socket, :insider_vote, true)}
  end

  @impl true
  def handle_event("judge", %{"vote" => "nay"}, socket) do
    :ok = Game.Manager.judge(socket.assigns.game_ref, socket.assigns.me, false)
    {:noreply, assign(socket, :insider_vote, false)}
  end

  @impl true
  def handle_event("accuse", %{"accused" => accused}, socket) do
    :ok = Game.Manager.accuse(socket.assigns.game_ref, socket.assigns.me, accused)
    {:noreply, socket}
  end

  @impl true
  def handle_event("ready", _value, socket) do
    :ok = Game.Sequencer.player_ready(socket.assigns.pub_state.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("not_ready", _value, socket) do
    :ok = Game.Sequencer.player_not_ready(socket.assigns.pub_state.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("untie", %{"player" => player}, socket) do
    :ok = Game.Manager.untie(socket.assigns.game_ref, player)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update, key, value}, socket) do
    {:noreply, assign(socket, key, value)}
  end

  @impl true
  def terminate(_reason, socket) do
    :ok = PubSub.unsubscribe(Game.PubSub, "insider:"<>socket.assigns.lobby_id)
    :ok
  end

end
