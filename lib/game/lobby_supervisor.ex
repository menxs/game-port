defmodule Game.LobbySupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_link(_options), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  def start_lobby() do
    id = gen_lobby_id()
    {:ok, _} = DynamicSupervisor.start_child(__MODULE__, {Game.Lobby, id})
    {:ok, id}
  end

  def exists_lobby?(id), do: Registry.lookup(Game.Bottleneck, id) != []

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  defp gen_lobby_id() do
    id =
      :rand.uniform(9999)
      |> Integer.to_string()
      |> String.pad_leading(4, "0")

    if exists_lobby?(id) do
      gen_lobby_id()
    else
      id
    end
  end
end
