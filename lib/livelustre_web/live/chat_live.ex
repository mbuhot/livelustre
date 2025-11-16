defmodule LivelustreWeb.ChatLive do
  use LivelustreWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <lustre-chat></lustre-chat>
    """
  end

  @impl true
  def handle_event("chat-message", %{"message" => message}, socket) do
    # Reverse the message as a fun server response
    reply = String.reverse(message)

    # Reply with just the map - the interceptor will handle event naming
    {:reply, %{reply: reply}, socket}
  end
end
