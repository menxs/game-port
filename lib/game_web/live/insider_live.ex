defmodule GameWeb.InsiderLive do
  use GameWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def render(%{state: :home} = assigns) do
    #Phoenix.View.render(GameWeb.InsiderView, "mockup.html", assigns)
    Phoenix.View.render(GameWeb.InsiderView, "homescreen.html", assigns)
  end

  @impl true
  def render(%{state: :lobby} = assigns) do
    Phoenix.View.render(GameWeb.InsiderView, "lobby.html", assigns)
  end

  @impl true
  def render(%{state: :game} = assigns) do
    Phoenix.View.render(GameWeb.InsiderView, "insider.html", assigns)
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, state: :home)}
  end

  @impl true
  def handle_event("create_lobby", _value, socket) do
    {:ok, id} = Game.LobbySupervisor.start_lobby()
    socket = socket
      |> assign(lobby: %{id: id})
      |> assign(state: :lobby)
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_lobby", %{"lobby_id" => id}, socket) do
    id = String.trim(id)
    if not Game.LobbySupervisor.exists_lobby?(id) do
      {:noreply, socket}
    else
      socket = socket
        |> assign(lobby: %{id: id})
        |> assign(state: :lobby)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_name", %{"name" => name}, socket) do
    name = String.trim(name)
    if name == "" do
      {:noreply, socket}
    else
      :ok = PubSub.subscribe(Game.PubSub, "lobby:"<>socket.assigns.lobby.id)
      :ok = Game.Lobby.add_player(lobby(socket), name)
      {:noreply, assign(socket, me: name)}
    end
  end

  @impl true
  def handle_event("play", _value, socket) do
    :ok = Game.Lobby.play(lobby(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_guessing", _value, socket) do
    :ok = Game.Manager.start_guessing(socket.assigns.game)
    {:noreply, socket}
  end

  @impl true
  def handle_event("word_not_found", _value, socket) do
    :ok = Game.Manager.word_not_found(socket.assigns.game)
    {:noreply, socket}
  end

  @impl true
  def handle_event("word_found", %{"player" => player}, socket) do
    :ok = Game.Manager.word_found(socket.assigns.game, player)
    {:noreply, socket}
  end

  @impl true
  def handle_event("judge", %{"vote" => "yay"}, socket) do
    :ok = Game.Manager.judge(socket.assigns.game, socket.assigns.me, true)
    {:noreply, assign(socket, :insider_vote, true)}
  end

  @impl true
  def handle_event("judge", %{"vote" => "nay"}, socket) do
    :ok = Game.Manager.judge(socket.assigns.game, socket.assigns.me, false)
    {:noreply, assign(socket, :insider_vote, false)}
  end

  @impl true
  def handle_event("accuse", %{"accused" => accused}, socket) do
    :ok = Game.Manager.accuse(socket.assigns.game, socket.assigns.me, accused)
    {:noreply, socket}
  end

  @impl true
  def handle_event("lobby_ready", _value, socket) do
    :ok = Game.Sequencer.player_ready(socket.assigns.lobby.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("lobby_not_ready", _value, socket) do
    :ok = Game.Sequencer.player_not_ready(socket.assigns.lobby.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("ready", _value, socket) do
    :ok = Game.Sequencer.player_ready(socket.assigns.insider.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("not_ready", _value, socket) do
    :ok = Game.Sequencer.player_not_ready(socket.assigns.insider.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("untie", %{"player" => player}, socket) do
    :ok = Game.Manager.untie(socket.assigns.game, player)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update, key, value}, socket) do
    {:noreply, assign(socket, key, value)}
  end

  @impl true
  def handle_info({:start, :game, game}, socket) do
    :ok = PubSub.subscribe(Game.PubSub, "insider:"<>socket.assigns.lobby.id)
    {:ok, state} = Game.Manager.get_state(game)
    {:ok, info} = Game.Manager.get_info(game, socket.assigns.me)
    socket = socket
      |> assign(:game, game)
      |> assign(:insider, state)
      |> assign(:insider_info, info)
      |> assign(:insider_vote, false)
      |> assign(:state, :game)
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:me] do
      :ok = PubSub.unsubscribe(Game.PubSub, "lobby:"<>socket.assigns.lobby.id)
      :ok = Game.Lobby.remove_player(lobby(socket), socket.assigns.me)
    end
    if socket.assigns[:insider] do
      :ok = PubSub.unsubscribe(Game.PubSub, "insider:"<>socket.assigns.lobby.id)
    end
    :ok
  end

  defp lobby(socket), do: lobby_name(socket.assigns.lobby.id)
  defp lobby_name(id), do: {:via, Registry, {Game.Bottleneck, id}}


end
