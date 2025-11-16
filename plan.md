# Design Document: Phoenix LiveView + Lustre Components Architecture

## Overview

This architecture integrates Lustre (Gleam) components as Web Components within Phoenix LiveView applications. Lustre handles rich client-side UI interactions using the Elm Architecture, while LiveView manages routing, authentication, and server state. Communication flows bidirectionally: LiveView updates flow down via HTML attributes, and component events flow up via LiveView socket effects.

## Goals

1. **Type-safe UI logic** - All component logic written in Gleam with full type safety
1. **Clean separation** - LiveView owns navigation/auth/server state; Lustre owns UI interactions
1. **Minimal ceremony** - No hooks, no per-component wiring, just register and use
1. **Natural integration** - Custom elements render directly in HEEx templates
1. **Efficient updates** - Only meaningful state changes cross the socket boundary

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Phoenix LiveView                     │
│  • Routing, auth, initial data loading                  │
│  • Server-side state management                         │
│  • Renders custom elements in HEEx                      │
└─────────────────┬───────────────────────────────────────┘
                  │
        Attributes│↓ (LiveView → Lustre)
                  │↑ Events via socket (Lustre → LiveView)
                  │
┌─────────────────▼───────────────────────────────────────┐
│              Web Components (Lustre)                    │
│  • Custom elements (e.g., <lustre-counter>)             │
│  • Pure Gleam/Elm Architecture                          │
│  • Rich client interactions                             │
│  • Effects for LiveView communication                   │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
my_app/
├── assets/
│   ├── js/
│   │   ├── app.js                    # Phoenix app entry, registers Lustre components
│   │   └── lustre_components.js      # Component registration
│   ├── css/
│   ├── gleam_components/             # Gleam project for UI components
│   │   ├── gleam.toml                # Gleam dependencies
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── counter.gleam
│   │   │   │   ├── form.gleam
│   │   │   │   └── chart.gleam
│   │   │   └── effects/
│   │   │       ├── liveview.gleam    # LiveView communication effects
│   │   │       └── liveview_ffi.mjs  # JavaScript FFI for socket access
│   │   └── build/                    # Gleam build output (gitignored)
│   └── package.json
├── lib/
│   └── my_app_web/
│       └── live/
│           └── page_live.ex          # LiveView modules
└── mix.exs
```

## Component Pattern

### Gleam Component Structure

Every Lustre component follows this pattern:

```gleam
// assets/gleam_components/src/components/example.gleam
import lustre/component
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import effects/liveview
import gleam/json

// 1. Model - component state
pub type Model {
  Model(
    // component-specific fields
  )
}

// 2. Msg - update messages
pub type Msg {
  // User interactions
  SomeAction
  // Server updates
  UpdateFromServer(NewData)
}

// 3. Init - accepts primitive values for attributes
pub fn init(initial_value: Type) -> #(Model, Effect(Msg)) {
  #(Model(...), effect.none())
}

// 4. Update - pure state transitions + effects
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SomeAction -> {
      let new_model = // ... update model
      let effect = liveview.push("event_name", 
        json.object([#("key", json.value(...))]))
      #(new_model, effect)
    }
    UpdateFromServer(data) -> 
      #(Model(...), effect.none())
  }
}

// 5. View - render function
pub fn view(model: Model) -> Element(Msg) {
  html.div([], [...])
}

// 6. Register - define custom element
pub fn register() {
  component.register(
    tag: "lustre-example",
    init: init,
    update: update,
    view: view,
    on_attribute_change: on_attribute_change
  )
}

// 7. Attribute change handler
fn on_attribute_change(name: String, value: String) -> Msg {
  case name {
    "some-attr" -> UpdateFromServer(parse(value))
    _ -> // default
  }
}
```

### Key Principles

- **Init takes primitives** - attributes are strings/numbers, not complex objects
- **Effects for server communication** - use `liveview.push()` effect, never imperative calls
- **Attribute changes trigger messages** - LiveView updates flow through `on_attribute_change`
- **Pure update function** - no side effects, just `#(Model, Effect(Msg))`

## LiveView Effect System

### Effect Module

```gleam
// assets/gleam_components/src/effects/liveview.gleam
import gleam/json
import lustre/effect.{type Effect}

/// Push an event to LiveView with JSON payload
pub fn push(event: String, payload: json.Json) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    do_push(event, payload)
  })
}

@external(javascript, "./liveview_ffi.mjs", "push_event")
fn do_push(event: String, payload: json.Json) -> Nil
```

### FFI Implementation

```javascript
// assets/gleam_components/src/effects/liveview_ffi.mjs
export function push_event(event, payload) {
  // Find the custom element that triggered this effect
  const element = findCallingElement();
  
  if (!element) {
    console.warn("Cannot push event: no element context");
    return;
  }
  
  // Walk up DOM to find LiveView container
  let current = element;
  while (current) {
    if (window.liveSocket) {
      const view = window.liveSocket.getViewByEl(current);
      if (view) {
        view.pushEvent(event, payload);
        return;
      }
    }
    current = current.parentElement;
  }
  
  console.warn("Cannot push event: no LiveView found");
}

function findCallingElement() {
  // Use event target or active element as proxy for calling context
  return document.activeElement?.shadowRoot?.host || document.activeElement;
}
```

### Typed Event Helpers (Optional)

```gleam
// assets/gleam_components/src/effects/liveview.gleam

/// Type-safe counter events
pub fn counter_changed(count: Int) -> Effect(msg) {
  push("counter_changed", json.object([
    #("count", json.int(count))
  ]))
}

/// Type-safe form events
pub fn form_submitted(data: FormData) -> Effect(msg) {
  push("form_submitted", encode_form_data(data))
}
```

## Component Registration

### JavaScript Registration File

```javascript
// assets/js/lustre_components.js
import * as Counter from "../gleam_components/build/dev/javascript/gleam_components/components/counter.mjs";
import * as Form from "../gleam_components/build/dev/javascript/gleam_components/components/form.mjs";
import * as Chart from "../gleam_components/build/dev/javascript/gleam_components/components/chart.mjs";

export function registerLustreComponents() {
  Counter.register();
  Form.register();
  Chart.register();
  // Add new components here
}
```

### Application Entry Point

```javascript
// assets/js/app.js
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { registerLustreComponents } from "./lustre_components"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken }
})

// Make socket globally available for Lustre effects
window.liveSocket = liveSocket

// Register all Lustre components as custom elements
registerLustreComponents()

// Connect LiveView
liveSocket.connect()
```

## LiveView Integration

### Using Components in Templates

```elixir
defmodule MyAppWeb.PageLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, items: [])}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>My Page</h1>
      
      <!-- Render Lustre component with attributes -->
      <lustre-counter count={@count}></lustre-counter>
      
      <!-- Complex data as JSON-encoded attributes -->
      <lustre-form 
        items={Jason.encode!(@items)}
        config={Jason.encode!(%{mode: "edit"})}
      >
      </lustre-form>
    </div>
    """
  end

  # Handle events from Lustre components
  def handle_event("counter_changed", %{"count" => count}, socket) do
    {:noreply, assign(socket, count: count)}
  end

  def handle_event("form_submitted", %{"data" => data}, socket) do
    # Process form data
    {:noreply, socket}
  end
end
```

### Communication Patterns

**LiveView → Lustre** (attributes):

```elixir
# Update triggers re-render with new attribute values
{:noreply, assign(socket, count: new_count)}
```

**Lustre → LiveView** (effects):

```gleam
// In component update function
liveview.push("event_name", json.object([...]))
```

## Build Process

### Gleam Configuration

```toml
# assets/gleam_components/gleam.toml
name = "gleam_components"
version = "1.0.0"
target = "javascript"

[dependencies]
gleam_stdlib = ">= 0.34.0 and < 2.0.0"
lustre = ">= 4.0.0 and < 5.0.0"
gleam_json = ">= 1.0.0 and < 2.0.0"

[javascript]
runtime = "browser"
```

### Mix Aliases

```elixir
# mix.exs
defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup"],
    
    "assets.setup": [
      "tailwind.install --if-missing",
      "esbuild.install --if-missing",
      "cmd --cd assets npm install",
      "cmd --cd assets/gleam_components gleam deps download"
    ],
    
    "assets.build": [
      "cmd --cd assets/gleam_components gleam build --target javascript",
      "tailwind my_app",
      "esbuild my_app"
    ],
    
    "assets.deploy": [
      "cmd --cd assets/gleam_components gleam build --target javascript",
      "tailwind my_app --minify",
      "esbuild my_app --minify",
      "phx.digest"
    ],
    
    test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
  ]
end
```

### Development Watchers

```elixir
# config/dev.exs
config :my_app, MyAppWeb.Endpoint,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:my_app, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:my_app, ~w(--watch)]},
    # Watch Gleam files and rebuild
    gleam: {Path.expand("assets"), 
      ["sh", "-c", "cd gleam_components && gleam build --target javascript"], 
      []}
  ]
```

### Build Flow

1. **Gleam builds** → `assets/gleam_components/build/dev/javascript/`
1. **esbuild imports** Gleam output and bundles → `priv/static/assets/app.js`
1. **Components register** on page load
1. **Custom elements** available in templates

The Gleam build output never needs to be in `priv/static/` - it’s an intermediate artifact consumed by esbuild.

## Usage Examples

### Simple Counter

```gleam
// Component
pub type Model { Model(count: Int) }
pub type Msg { Increment | Decrement | SetCount(Int) }

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Increment -> {
      let new_count = model.count + 1
      #(Model(new_count), liveview.push("count_changed", 
        json.object([#("count", json.int(new_count))])))
    }
    // ...
  }
}
```

```elixir
# LiveView
<lustre-counter count={@count}></lustre-counter>
```

### Form with Complex State

```gleam
// Component receives JSON
pub fn init(items_json: String) -> #(Model, Effect(Msg)) {
  let items = json.decode(items_json, items_decoder)
  #(Model(items: items), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Submit -> {
      #(model, liveview.push("form_submitted",
        json.object([#("items", encode_items(model.items))])))
    }
  }
}
```

```elixir
# LiveView
<lustre-form items={Jason.encode!(@items)}></lustre-form>

def handle_event("form_submitted", %{"items" => items}, socket) do
  # Process items
end
```

### Chart with Real-time Updates

```gleam
// Component
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    DataPointClicked(point) -> {
      #(model, liveview.push("chart_point_clicked",
        json.object([
          #("x", json.float(point.x)),
          #("y", json.float(point.y))
        ])))
    }
    UpdateData(new_data) -> 
      #(Model(..model, data: new_data), effect.none())
  }
}
```

```elixir
# LiveView streams new data
def handle_info({:new_data, data}, socket) do
  {:noreply, assign(socket, chart_data: data)}
end

<lustre-chart data={Jason.encode!(@chart_data)}></lustre-chart>
```

## Testing Strategy

### Gleam Component Tests

```gleam
// Pure unit tests for update logic
import gleeunit/should

pub fn increment_updates_count_test() {
  let model = Model(count: 5)
  let #(new_model, _effect) = update(model, Increment)
  
  new_model.count
  |> should.equal(6)
}

pub fn increment_emits_event_test() {
  let model = Model(count: 5)
  let #(_model, effect) = update(model, Increment)
  
  // Effect inspection would require testing helpers
  effect
  |> should_emit_event("count_changed")
}
```

### LiveView Tests

```elixir
test "counter interaction", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  
  # Simulate event from Lustre component
  view
  |> render_hook("counter_changed", %{"count" => 42})
  
  assert render(view) =~ "42"
end
```

## Deployment Considerations

### Production Build

Ensure CI/CD runs:

```bash
cd assets/gleam_components && gleam deps download
cd assets/gleam_components && gleam build --target javascript
cd assets && npm ci
mix assets.deploy
```

### Asset Digests

The `phx.digest` task automatically fingerprints the bundled `app.js`, which includes all Gleam components.

### Caching

- Gleam build output can be cached between CI runs (cache `assets/gleam_components/build/`)
- Standard Phoenix static asset caching applies

## Benefits Summary

1. **Type Safety** - Gleam’s type system catches errors at compile time
1. **Functional Purity** - Elm Architecture ensures predictable state management
1. **Clear Boundaries** - LiveView and Lustre have well-defined responsibilities
1. **Simple Integration** - No hooks, minimal JavaScript, just custom elements
1. **Testability** - Pure functions easy to test in isolation
1. **Developer Experience** - Gleam’s tooling + Phoenix’s live reload
1. **Performance** - Only meaningful updates cross socket boundary

## Migration Path

To add this to an existing Phoenix project:

1. Add `assets/gleam_components/` directory with `gleam.toml`
1. Update `mix.exs` aliases for Gleam builds
1. Create initial component and effect modules
1. Update `assets/js/app.js` to register components
1. Use custom elements in LiveView templates
1. Incrementally migrate interactive UI to Lustre components

-----

**Document Version:** 1.0  
**Last Updated:** 2025-11-16  
**Author:** Mike (with Claude)