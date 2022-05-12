defmodule Game.Manager do
  use GenServer

  alias Phoenix.PubSub

  ## Client API

  def start_link(init_args, opts) do
    GenServer.start_link(__MODULE__, init_args, opts)
  end

  def get_state(manager) do
    GenServer.call(manager, :get_state)
  end

  def get_info(manager, player) do
    GenServer.call(manager, {:get_info, player})
  end

  def start_guessing(manager) do
    GenServer.call(manager, :start_guessing)
  end

  def word_not_found(manager) do
    GenServer.call(manager, :word_not_found)
  end

  def word_found(manager, player) do
    GenServer.call(manager, {:word_found, player})
  end

  def judge(manager, player, vote) do
    GenServer.call(manager, {:judge, player, vote})
  end

  def accuse(manager, player, accused) do
    GenServer.call(manager, {:accuse, player, accused})
  end

  def resolve_game(manager) do
    GenServer.call(manager, :resolve_game)
  end

  def untie(manager, player) do
    GenServer.call(manager, {:untie, player})
  end

  ## GenServer Callbacks

  @impl true
  def init({id, names}) do

    player_info = %{
      role: :commons,
      vote: false,
      accuses: :none,
    }

    players =
      names                                           # The names
      |> Enum.map(fn name -> {name, player_info} end) # Add the basic info
      |> Enum.shuffle()                               # Randomize the order
      |> List.update_at(0,                            # First player is the master
        fn {name, info} ->
          {name, %{info | role: :master}}
        end)
      |> List.update_at(1,                            # Second player is the insider
        fn {name, info} ->
          {name, %{info | role: :insider}}
        end)
      |> Enum.shuffle()                               # Randomize the order again
      |> Map.new()                                    # Convert it into a map

    {:ok, seq} = Game.Sequencer.start_link({"insider:"<>id, names}, [])

    state = %{
      id: id,
      phase: :setup,
      seq: seq,
      players: players,
      timer: 3 * 60,
      timeout_date: nil,
      word: Enum.random(Game.Words.list()),
      player_foundit: :tbd,
      votes: :tbd,
      accusations: :tbd,
      winner: :tbd
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, client_state(state)}, state}
  end

  @impl true
  def handle_call({:get_info, player}, _from, state) do
    info =
      case state.players[player].role do
        :master ->
          %{role: :master, word: state.word}
        :insider ->
          %{role: :insider, word: state.word}
        :commons ->
          %{role: :commons}
      end
    {:reply, {:ok, info}, state}
  end

  @impl true
  def handle_call(:start_guessing, _from, %{phase: :setup} = state) do
    state = %{state |
      phase: :guessing,
      timeout_date: DateTime.utc_now |> DateTime.add(state.timer)
    }
    :ok = Game.Sequencer.apply_on_timer(state.seq, &word_not_found/1, [self()], state.timer * 1000)
    broadcast(state, {:update, :insider, client_state(state)})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:word_not_found, _from, %{phase: :guessing} = state) do
    :ok = Game.Sequencer.cancel(state.seq)
    state = %{state | phase: {:end, :timeout}, winner: :none}
    broadcast(state, {:update, :insider, state})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:word_found, player}, _from, %{phase: :guessing} = state) do

    :ok = Game.Sequencer.cancel(state.seq)

    state = %{state |
      player_foundit: player,
      phase: :discussion,
      timeout_date: DateTime.utc_now |> DateTime.add(state.timer)
    }

    :ok = Game.Sequencer.apply_on_both(state.seq, &resolve_game/1, [self()], state.timer * 1000)

    broadcast(state, {:update, :insider, client_state(state)})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:judge, player, vote}, _from,  %{phase: :discussion} = state) do
    state =
      if state.player_foundit != player do # The player that guessed the word cant vote
        put_in(state, [:players, player, :vote], vote)
      else
        state
      end
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:accuse, player, accused}, _from, %{phase: :discussion} = state) do
    state =
      if (state.player_foundit != accused)            # Cant accuse the player that guessed the word
      and (state.players[accused].role != :master) do # Cant accuse the master
        put_in(state, [:players, player, :accuses], accused)
      else
        state
      end
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:resolve_game, _from, %{phase: :discussion} = state) do

    votes_count = # Number of players that think the insider guessed the word
      state.players                                       # The players
      |> Map.values()                                     # Get the info
      |> Enum.map(fn info -> Map.fetch!(info, :vote) end) # Get the votes
      |> Enum.count(& &1)                                 # Count the votes

    votes = %{
      result: votes_count > div(length(Map.keys(state.players))-1, 2),
      count: votes_count,
      total: length(Map.keys(state.players))-1,
      role: state.players[state.player_foundit].role
    }

    empty_fallback = # If no player accuses, everyone has 0 accusations
      state.players
      |> Map.keys()
      |> Enum.map(fn player -> {player, 0} end)
      |> (&{0, &1}).()

    accusations = # List of players with most accusations
      state.players                                          # The players
      |> Map.values()                                        # Get the info
      |> Enum.map(fn info -> Map.fetch!(info, :accuses) end) # Get the accusations
      |> Enum.reject(& &1==:none)                            # Drop the empty accusations
      |> Enum.frequencies()                                  # Count how many of each one there are (frequency)
      |> Enum.group_by(fn {_, freq} -> freq end)             # Group them by the frequency
      |> Enum.max_by(&elem(&1, 0), fn -> empty_fallback end) # Take the accusations with maximum frequency
      |> (&elem(&1, 1)).()                                   # Get rid of the frequency from group_by
      |> Enum.map(fn {player, _} -> player end)              # Get rid of the frequencies

    {phase, winner, accusations} = resolve_game(state, votes, accusations)

    state = %{state |
      phase: phase,
      votes: votes,
      accusations: accusations,
      winner: winner
    }
    broadcast(state, {:update, :insider, state})
    if state.phase == :untie do
      {:reply, :ok, state}
    else
      {:stop, :normal, :ok, state}
    end
  end

  @impl true
  def handle_call({:untie, player}, _from, state) do
    if player in state.accusations do
      {:win, winner, accusations} = resolve_accusing(state, [player])
      state = %{state |
        phase: {:end, :untie},
        accusations: accusations,
        winner: winner
      }
      broadcast(state, {:update, :insider, state})
      {:stop, :normal, :ok, state}
    else
      {:reply, :error, state}
    end
  end

  defp resolve_game(state, votes, accusations) do
    case resolve_voting(votes) do
      {:win, winner} ->
        {{:end, :vote}, winner, accusations}
      :continue ->
        case resolve_accusing(state, accusations) do
          :tie ->
            {:untie, :tbd, accusations}
          {:win, winner, accusations} ->
            {{:end, :acc}, winner, accusations}
        end
    end
  end

  defp resolve_voting(%{role: :insider, result: true}) do
    {:win, :commons}
  end
  defp resolve_voting(%{role: :insider, result: false}) do
    {:win, :insider}
  end
  defp resolve_voting(%{role: :commons, result: true}) do
    {:win, :insider_and_guesser}
  end
  defp resolve_voting(_) do
    :continue
  end

  defp resolve_accusing(state, [player]) do
    accusations = %{
      accused: player,
      role: state.players[player].role
    }
    if accusations.role == :insider do
      {:win, :commons, accusations}
    else
      {:win, :insider, accusations}
    end
  end
  defp resolve_accusing(_, _) do
    :tie
  end

  defp broadcast(state, msg) do
    PubSub.broadcast(Game.PubSub, "insider:"<>state.id, msg)
  end

  defp client_state(state) do
    state =
      Map.update!(state, :players,&Map.new(Enum.map(&1,
        fn
          {name , %{role: :master}} -> {name, %{role: :master}}
          {name, %{role: _}} -> {name, %{role: :unknown}}
        end)))

    if state.phase == :setup or state.phase == :guessing do
      Map.drop(state, [:word])
    else
      state
    end
  end

end
