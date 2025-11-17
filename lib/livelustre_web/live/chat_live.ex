defmodule LivelustreWeb.ChatLive do
  use LivelustreWeb, :live_view

  @random_messages [
    "☕ Coffee break time!",
    "🚀 Deploy successful!",
    "🐛 Bug squashed!",
    "📊 Analytics update: Traffic is up!",
    "🎉 Congratulations on your milestone!",
    "⚡ Server performing optimally",
    "🔔 Reminder: Team standup in 10 minutes"
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Send a random message every 5 seconds
      :timer.send_interval(5000, self(), :send_random_message)
    end

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
    {:reply, %{reply: reply}, socket}
  end

  @impl true
  def handle_info(:send_random_message, socket) do
    message = Enum.random(@random_messages)
    {:noreply, push_event(socket, "server-message", %{message: message})}
  end
end
