# Livelustre

A demonstration of integrating [Lustre](https://hexdocs.pm/lustre) (Gleam's web framework) with Phoenix LiveView to create rich, interactive client-side components with server-side business logic.

## What is this?

This project showcases how to build modern web applications by combining:

- **Phoenix LiveView** for data fetching and initial page rendering
- **Lustre** components written in Gleam for type-safe, functional client-side UI
- **Bidirectional communication** between LiveView and Lustre via custom events

## Demo Components

### Counter (`/counter`)

The counter demonstrates server-driven state updates via HTML attributes. When you click increment or decrement, the Lustre component sends an event to LiveView, which performs the arithmetic and updates its assigns. LiveView's DOM patching automatically updates the `count` attribute on the custom element, triggering Lustre's `on_attribute_change` handler to update the UI.

**Key files:**
- [counter.gleam](assets/lustre_components/src/components/counter.gleam) - Lustre component
- [counter_live.ex](lib/livelustre_web/live/counter_live.ex) - LiveView module

```elixir
# LiveView renders the count into an attribute on the custom element
~H"""
<lustre-counter id="counter" count={@count}></lustre-counter>
"""
```

```gleam
// Lustre component watches for attribute changes
component.on_attribute_change("count", fn(value) {
  int.parse(value)
  |> result.map(SetCount)
  |> result.replace_error(Nil)
})
```

```gleam
// Button clicks will dispatch Increment or Decrement messages, which trigger a LiveView event effect.
case msg {
  Increment -> #(model, send_count_event("increment", model.count))
  Decrement -> #(model, send_count_event("decrement", model.count))
  ...
}
```

```elixir
# LiveView receives the event and updates assigns, triggering automatic re-render
def handle_event("increment", %{"count" => count}, socket) do
  {:noreply, assign(socket, count: count + 1)}
end
```

 The event cycle is familiar to LiveView, but now gives the frontend explicit control over how attribute changes are applied to the UI.

### Chat (`/chat`)

The chat demonstrates bidirectional communication with both request-reply and server-initiated push. Users send messages that get reversed by the server (request-reply pattern), while the server independently pushes random notifications every 5 seconds using LiveView's `push_event`.

**Key files:**
- [chat.gleam](assets/lustre_components/src/components/chat.gleam) - Lustre component
- [chat_live.ex](lib/livelustre_web/live/chat_live.ex) - LiveView module

```elixir
# Server sends periodic updates to the client
def handle_info(:send_random_message, socket) do
  message = Enum.random(@random_messages)
  {:noreply, push_event(socket, "server-message", %{message: message})}
end
```

```gleam
// Lustre subscribes to server-initiated events on mount
pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let subscribe_effect = subscribe_to_server_messages()
  #(Model(messages: [], input: ""), subscribe_effect)
}
```

LiveView's standard patterns for event replies and server-pushed events can be used to communicate with the client.

### Checkout (`/checkout`)

A complete e-commerce checkout flow showcasing the request-reply pattern with server-side validation. The Lustre component maintains local UI state but defers to the server for business logic like address validation and discount code verification. State persists in localStorage and syncs with URL parameters for bookmarkable progress.

**Key files:**
- [checkout.gleam](assets/lustre_components/src/components/checkout.gleam) - Lustre component
- [checkout_live.ex](lib/livelustre_web/live/checkout_live.ex) - LiveView module
- [checkout_test.gleam](assets/lustre_components/test/components/checkout_test.gleam) - Component tests
- [commerce.ex](lib/livelustre/commerce.ex) - Business logic module

```gleam
// Lustre sends request and handles reply
liveview_client.push_event(
  "lustre-checkout",
  "validate-address",
  address_payload,
  option.Some(handle_validation_reply)
)
```

```elixir
# LiveView validates and replies
def handle_event("validate-address", address, socket) do
  case Commerce.validate_address(address) do
    {:ok} -> {:reply, %{valid: true}, socket}
    {:error, errors} -> {:reply, %{valid: false, errors: errors}, socket}
  end
end
```

Complex client-side forms can maintain rich interactivity while keeping business logic on the server through the request-reply pattern. Includes comprehensive UI testing using Lustre's simulate module.

## Architecture Highlights

- **Type-safe client code**: Lustre components are written in Gleam and compiled to JavaScript
- **Clear separation of concerns**: Business logic lives in Elixir (`lib/`), presentation in Gleam (`assets/lustre_components/`)
- **Custom Elements**: Lustre components register as Web Components (e.g., `<lustre-checkout>`)
- **Effect handlers**: Direct LiveView channel communication from Lustre effects
- **Testing**: UI-driven tests using Lustre's simulate module for realistic component testing

## Getting Started

```bash
# Install dependencies
mix setup

# Start the Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to see the demos.

## Project Structure

```
lib/livelustre/           # Elixir business logic
lib/livelustre_web/live/  # Phoenix LiveView modules
assets/lustre_components/ # Gleam/Lustre components
  src/components/         # Component implementations
  test/components/        # Component tests
```

## Running Tests

```bash
# Run all tests (Elixir + Gleam)
mix test

# Run only Lustre component tests
cd assets/lustre_components && gleam test
```

## Building Assets

```bash
# Build assets for development
mix assets.build

# Build optimized assets for production
mix assets.deploy
```

## Learn More

### About the Stack
- Phoenix Framework: https://www.phoenixframework.org/
- Phoenix LiveView: https://hexdocs.pm/phoenix_live_view
- Lustre: https://hexdocs.pm/lustre
- Gleam: https://gleam.run/
