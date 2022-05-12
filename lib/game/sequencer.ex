defmodule Game.Sequencer do
  use GenServer

  alias Phoenix.PubSub

  ## Client API

  def start_link(init_args, opts) do
    GenServer.start_link(__MODULE__, init_args, opts)
  end

  def player_ready(seq, player) do
    GenServer.call(seq, {:player_ready, player})
  end

  def player_not_ready(seq, player) do
    GenServer.call(seq, {:player_not_ready, player})
  end

  def update_players(seq, players) do
    GenServer.call(seq, {:update_players, players})
  end

  def apply_on_ready(seq, funct, args, min \\ 0) do
    GenServer.call(seq, {:apply_on_ready, funct, args, min})
  end

  def apply_on_timer(seq, funct, args, time) do
    GenServer.call(seq, {:apply_on_timer, funct, args, time})
  end

  def apply_on_both(seq, funct, args, time) do
    GenServer.call(seq, {:apply_on_both, funct, args, time})
  end

  def cancel(seq) do
    GenServer.call(seq, :cancel)
  end

  ## GenServer Callbacks

  @impl true
  def init({topic, names}) do

    ready =
      names
      |> Enum.map(fn name -> {name, false} end)
      |> Map.new()

    state = %{
      topic: topic,
      seq_on_ready: false,
      seq_on_timer: false,
      ready: ready,
      timer: false,
      timer_ref: nil,
      funct: nil,
      args: nil,
      min: 0,
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:apply_on_ready, funct, args, min}, _from, state) do
    state = %{state |
    ready: reset_ready(state.ready),
    funct: funct,
    args: args,
    min: min,
    seq_on_ready: true}
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:apply_on_timer, funct, args, time}, _from, state) do
    timer_ref = Process.send_after(self(), :time_apply, time)
    state = %{state |
    funct: funct,
    args: args,
    timer_ref: timer_ref,
    seq_on_timer: true}
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:apply_on_both, funct, args, time}, _from, state) do
    timer_ref = Process.send_after(self(), :time_apply, time)
    state = %{state |
    funct: funct,
    args: args,
    timer_ref: timer_ref,
    min: 0,
    seq_on_timer: true,
    seq_on_ready: true}
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:player_ready, player}, _from, state) do
    state = put_in(state, [:ready, player], true)
    if state.seq_on_ready
    and length(Map.keys(state.ready)) >= state.min
    and Enum.all?(state.ready, fn {_, ready}-> ready end) do
      spawn(fn -> apply(state.funct, state.args) end)
      state = clear_seq(state)
      broadcast(state)
      {:reply, :ok, state}
    else
      broadcast(state)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:player_not_ready, player}, _from, state) do
    state = put_in(state, [:ready, player], false)
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_players, players}, _from, state) do
    state = %{ state |
      ready:
        Enum.map(players,
          fn player ->
            if state.ready[player] do
              {player, state.ready[player]}
            else
              {player, false}
            end
          end)
        |> Map.new()
    }
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:cancel, _from, state) do
    state = clear_seq(state)
    broadcast(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:time_apply, state) do
    if state.seq_on_timer do
      spawn(fn -> apply(state.funct, state.args) end)
      state = clear_seq(state)
      broadcast(state)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  defp clear_seq(state) do
    if state.timer_ref != nil do
      Process.cancel_timer(state.timer_ref)
    end
    %{state |
      seq_on_ready: false,
      seq_on_timer: false,
      ready: reset_ready(state.ready),
      timer_ref: nil
    }
  end

  defp reset_ready(players) do
    players
    |> Enum.map(fn {name, _} -> {name, false} end)
    |> Map.new()
  end

  defp broadcast(state) do
    msg = {:update, :ready, %{min: state.min, players: state.ready}}
    PubSub.broadcast(Game.PubSub, state.topic, msg)
  end
end
