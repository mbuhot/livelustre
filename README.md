# Livelustre

A demonstration of integrating [Lustre](https://hexdocs.pm/lustre) (Gleam's web framework) with Phoenix LiveView to create rich, interactive client-side components with server-side business logic.

## What is this?

This project showcases how to build modern web applications by combining:

- **Phoenix LiveView** for data fetching and initial page rendering
- **Lustre** components written in Gleam for type-safe, functional client-side UI
- **Bidirectional communication** between LiveView and Lustre via custom events

## Demo Components

### Counter (`/counter`)
A simple incrementing counter that demonstrates:
- Basic Lustre component with state management
- Event communication from Lustre to LiveView
- LiveView assign updates to Lustre

### Chat (`/chat`)
A chat interface showing:
- Messaging from client to server
- Handling user input

### Checkout (`/checkout`)
A complete e-commerce checkout flow featuring:
- Multi-step wizard (Customer Details → Shipping Address → Order Review → Marketing Consent)
- Server-side validation (address verification, discount codes)
- LocalStorage integration for state persistence
- URL parameter synchronization
- Comprehensive UI testing with `lustre/dev/simulate`

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

### Phoenix Resources
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
- Source: https://github.com/phoenixframework/phoenix
