import gleam/int
import gleam/json
import gleam/option
import gleam/result
import liveview_client
import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

// TYPES -----------------------------------------------------------------------

pub type Model {
  Model(count: Int)
}

pub type Msg {
  Increment
  Decrement
  SetCount(Int)
}

// INIT ------------------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(Model(count: 0), effect.none())
}

// EFFECTS ---------------------------------------------------------------------

fn send_count_event(event_name: String, count: Int) -> Effect(Msg) {
  let payload = json.object([#("count", json.int(count))])
  liveview_client.push_event("lustre-counter", event_name, payload, option.None)
}

// UPDATE ----------------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Increment -> #(model, send_count_event("increment", model.count))
    Decrement -> #(model, send_count_event("decrement", model.count))
    SetCount(count) -> #(Model(count: count), effect.none())
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  container([
    html.h1([attribute.class("text-4xl font-bold mb-8 text-center")], [
      element.text("Lustre Counter Demo"),
    ]),
    card([
      card_body([
        card_title("Phoenix LiveView + Lustre (Gleam)"),
        info_alert(),
        counter_stat(model.count),
        counter_buttons(model.count),
      ]),
    ]),
  ])
}

fn container(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("container mx-auto max-w-2xl mt-8 px-4")], children)
}

fn card(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("card bg-base-100 shadow-xl")], children)
}

fn card_body(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("card-body")], children)
}

fn card_title(text: String) -> Element(msg) {
  html.h2([attribute.class("card-title")], [element.text(text)])
}

fn info_icon() -> Element(msg) {
  svg.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("fill", "none"),
      attribute.attribute("viewBox", "0 0 24 24"),
      attribute.class("stroke-current shrink-0 w-6 h-6"),
    ],
    [
      svg.path([
        attribute.attribute("stroke-linecap", "round"),
        attribute.attribute("stroke-linejoin", "round"),
        attribute.attribute("stroke-width", "2"),
        attribute.attribute(
          "d",
          "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
        ),
      ]),
    ],
  )
}

fn info_alert() -> Element(msg) {
  html.div([attribute.class("alert alert-info")], [
    info_icon(),
    html.span([], [
      element.text(
        "This counter is a Lustre (Gleam) component rendered as a custom element. Click the buttons to see bidirectional communication between Lustre and LiveView!",
      ),
    ]),
  ])
}

fn counter_stat(count: Int) -> Element(msg) {
  html.div([attribute.class("stats shadow my-4")], [
    html.div([attribute.class("stat place-items-center")], [
      html.div([attribute.class("stat-title")], [element.text("Current Count")]),
      html.div([attribute.class("stat-value text-primary")], [
        element.text(int.to_string(count)),
      ]),
      html.div([attribute.class("stat-desc")], [
        element.text("Synced with LiveView"),
      ]),
    ]),
  ])
}

fn counter_buttons(count: Int) -> Element(Msg) {
  html.div([attribute.class("card-actions justify-center")], [
    html.div([attribute.class("join")], [
      html.button(
        [
          attribute.class("btn btn-primary join-item"),
          event.on_click(Decrement),
        ],
        [element.text("-")],
      ),
      html.div([attribute.class("btn join-item no-animation")], [
        element.text(int.to_string(count)),
      ]),
      html.button(
        [
          attribute.class("btn btn-primary join-item"),
          event.on_click(Increment),
        ],
        [element.text("+")],
      ),
    ]),
  ])
}

// COMPONENT -------------------------------------------------------------------

pub fn register() -> Result(Nil, lustre.Error) {
  let app =
    lustre.component(init, update, view, [
      component.on_attribute_change("count", fn(value) {
        int.parse(value)
        |> result.map(SetCount)
        |> result.replace_error(Nil)
      }),
    ])

  lustre.register(app, "lustre-counter")
}
