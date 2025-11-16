defmodule LivelustreWeb.CounterLive do
  use LivelustreWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <lustre-counter count={@count}></lustre-counter>
    """
  end

  @impl true
  def handle_event("counter-changed", %{"count" => count}, socket) do
    {:noreply, assign(socket, count: count)}
  end
end
