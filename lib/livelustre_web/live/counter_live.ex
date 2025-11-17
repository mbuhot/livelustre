defmodule LivelustreWeb.CounterLive do
  use LivelustreWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <lustre-counter id="counter" count={@count}></lustre-counter>
    """
  end

  @impl true
  def handle_event("increment", %{"count" => count}, socket) do
    new_count = count + 1
    {:noreply, assign(socket, count: new_count)}
  end

  @impl true
  def handle_event("decrement", %{"count" => count}, socket) do
    new_count = count - 1
    {:noreply, assign(socket, count: new_count)}
  end
end
