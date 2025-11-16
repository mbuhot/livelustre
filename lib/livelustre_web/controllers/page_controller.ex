defmodule LivelustreWeb.PageController do
  use LivelustreWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
