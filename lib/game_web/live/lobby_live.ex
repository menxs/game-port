defmodule GameWeb.LobbyLive do
  use GameWeb, :live_view

  alias Phoenix.PubSub

  @impl true
  def render(assigns) do
    if assigns.ingame? do
      Phoenix.View.render(GameWeb.LobbyView, "game.html", assigns)
    else
      Phoenix.View.render(GameWeb.LobbyView, "lobby.html", assigns)
    end
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if Game.LobbySupervisor.exists_lobby?(id) do
      {:ok,
        socket
        |> assign(ingame?: false) # TODO Check with the lobby if it is in game or not
        |> assign(lobby_id: id)
      }
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    if connected?(socket) do
      :ok = PubSub.subscribe(Game.PubSub, "lobby:"<>id)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_name", %{"name" => name}, socket) do
    name = String.trim(name)
    if name == "" do
      {:noreply, socket}
    else
      {:ok, info} = Game.Lobby.add_player(lobby(socket), name)

      socket = socket
        |> assign(me: name)
        |> assign(lobby: info)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("ready", _value, socket) do
    :ok = Game.Sequencer.player_ready(socket.assigns.lobby.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_event("not_ready", _value, socket) do
    :ok = Game.Sequencer.player_not_ready(socket.assigns.lobby.seq, socket.assigns.me)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update, key, value}, socket) do
    {:noreply, assign(socket, key, value)}
  end

  @impl true
  def handle_info({:start, :game_ref, game_ref}, socket) do
    {:noreply,
      socket
      |> assign(ingame?: true)
      |> assign(endscreen: false)
      |> assign(game_ref: game_ref)
    }
  end

  @impl true
  def handle_info(:endscreen, socket) do
    {:noreply, assign(socket, :endscreen, true)}
  end

  @impl true
  def terminate(_reason, socket) do
    :ok = PubSub.unsubscribe(Game.PubSub, "lobby:"<>socket.assigns.lobby_id)
    if socket.assigns[:me] do
      :ok = Game.Lobby.remove_player(lobby(socket), socket.assigns.me)
    end
    :ok
  end

  defp lobby(socket), do: lobby_name(socket.assigns.lobby_id)
  defp lobby_name(id), do: {:via, Registry, {Game.Bottleneck, id}}

end
