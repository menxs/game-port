defmodule GameWeb.HomeController do
  use GameWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def create(conn, _params) do
    {:ok, id} = Game.LobbySupervisor.start_lobby()
    redirect(conn, to: "/lobby/#{id}")
  end

  def join(conn, %{"id" => id}) do
    redirect(conn, to: "/lobby/#{String.trim(id)}")
  end
end
 
