defmodule Game.Lobby do
  use GenServer

  alias Phoenix.PubSub

  ## Client API

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, [name: {:via, Registry, {Game.Bottleneck, id}}])
  end

  def add_player(lobby, player) do
    GenServer.call(lobby, {:add_player, player})
  end

  def remove_player(lobby, player) do
    GenServer.call(lobby, {:remove_player, player})
  end

  def play(lobby) do
    GenServer.call(lobby, :play)
  end

  ## GenServer Callbacks

  @impl true
  def init(id) do
    {:ok, seq} = Game.Sequencer.start_link({"lobby:"<>id, []}, [])
    :ok = Game.Sequencer.apply_on_ready(seq, &play/1, [self()], 4)
    state = %{
      id: id,
      players: MapSet.new,
      seq: seq
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:add_player, player}, _from, state) do
    if MapSet.member?(state.players, player) do
      {:reply, :error, state}
    else
      state = %{state | players: MapSet.put(state.players, player)}
      :ok = Game.Sequencer.update_players(state.seq, MapSet.to_list(state.players))
      :ok = broadcast_state(state)
      {:reply, :ok, state}
    end
  end

  def handle_call({:remove_player, player}, _from, state) do
    state = %{state | players: MapSet.delete(state.players, player)}
    :ok = Game.Sequencer.update_players(state.seq, MapSet.to_list(state.players))
    :ok = broadcast_state(state)
    if state.players == MapSet.new() do
      {:stop, :normal, :ok, state}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:play, _from, state) do
    {:ok, game} = Game.Manager.start_link({state.id, MapSet.to_list(state.players)}, [])
    :ok = Game.Sequencer.apply_on_ready(state.seq, &play/1, [self()], 4)
    :ok = broadcast(state, {:start, :game, game})
    {:reply, :ok, state}
  end

  defp broadcast(state, msg) do
    PubSub.broadcast(Game.PubSub, "lobby:"<>state.id, msg)
  end
  defp broadcast_state(state) do
    broadcast(state, {:update, :lobby, state})
  end

end
