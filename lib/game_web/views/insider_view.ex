defmodule GameWeb.InsiderView do
  use GameWeb, :view
  use Phoenix.HTML

  def winner_phrase(assigns) do
    case assigns.winner do
      :insider ->
        ~L"""
        The insider <strong><%=insider_name(@players)%></strong> wins
        """
      :commons ->
        ~L"""
        The insider <strong><%=insider_name(@players)%></strong> loses
        """
      :insider_and_guesser ->
        ~L"""
        The insider <strong><%=insider_name(@players)%></strong>
        wins together with <strong><%=@player_foundit%></strong>
        """
      :none ->
        ~L"""
         Everyone loses, the insider was <strong><%=insider_name(@players)%></strong>
        """
      end
  end

  def insider_name(players) do
    {name, _} = Enum.find(players, fn {_, %{role: role}} -> role == :insider end)
    name
  end
end
