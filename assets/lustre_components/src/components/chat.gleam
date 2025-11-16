import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import liveview_client
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event

// TYPES -----------------------------------------------------------------------

pub type Message {
  Message(text: String, from: MessageFrom)
}

pub type MessageFrom {
  User
  Server
}

pub type Model {
  Model(messages: List(Message), input: String)
}

pub type Msg {
  UpdateInput(String)
  SendMessage
  ReceiveReply(String)
  ServerError(String)
}

// INIT ------------------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  #(Model(messages: [], input: ""), effect.none())
}

// EFFECTS ---------------------------------------------------------------------

fn decode_chat_reply(reply_data: Dynamic) -> Msg {
  // Decode the reply to extract the "reply" field
  let reply_decoder = {
    use text <- decode.field("reply", decode.string)
    decode.success(ReceiveReply(text))
  }

  decode.run(reply_data, reply_decoder)
  |> result.unwrap(ServerError("Failed to decode reply"))
}

fn send_message(text: String) -> Effect(Msg) {
  let payload = json.object([#("message", json.string(text))])
  liveview_client.push_event(
    "lustre-chat",
    "chat-message",
    payload,
    Some(decode_chat_reply),
  )
}

// UPDATE ----------------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UpdateInput(value) -> #(Model(..model, input: value), effect.none())

    SendMessage -> {
      case model.input {
        "" -> #(model, effect.none())
        text -> {
          // Add user message to history
          let new_message = Message(text: text, from: User)
          let new_messages = [new_message, ..model.messages]

          // Send message to LiveView and handle reply
          let eff = send_message(text)

          #(Model(messages: new_messages, input: ""), eff)
        }
      }
    }

    ReceiveReply(text) -> {
      // Add server reply to history
      let reply = Message(text: text, from: Server)
      let new_messages = [reply, ..model.messages]
      #(Model(..model, messages: new_messages), effect.none())
    }

    ServerError(error) -> {
      // Add error message to history
      let error_msg = Message(text: "Error: " <> error, from: Server)
      let new_messages = [error_msg, ..model.messages]
      #(Model(..model, messages: new_messages), effect.none())
    }
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("container mx-auto max-w-2xl mt-8 px-4")], [
    html.h1([attribute.class("text-4xl font-bold mb-8 text-center")], [
      element.text("💬 Lustre Chat"),
    ]),
    html.div([attribute.class("card bg-base-100 shadow-xl")], [
      html.div([attribute.class("card-body")], [
        // Chat messages area
        html.div(
          [
            attribute.class(
              "bg-base-200 rounded-lg p-4 h-96 overflow-y-auto mb-4 flex flex-col-reverse",
            ),
          ],
          [view_messages(model.messages)],
        ),
        // Input area
        html.div([attribute.class("form-control")], [
          html.div([attribute.class("join w-full")], [
            html.input([
              attribute.type_("text"),
              attribute.class("input input-bordered join-item flex-1"),
              attribute.placeholder("Type a message..."),
              attribute.value(model.input),
              event.on_input(UpdateInput),
              on_enter(SendMessage),
            ]),
            html.button(
              [
                attribute.class("btn btn-primary join-item"),
                event.on_click(SendMessage),
                attribute.disabled(model.input == ""),
              ],
              [
                svg.svg(
                  [
                    attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
                    attribute.attribute("fill", "none"),
                    attribute.attribute("viewBox", "0 0 24 24"),
                    attribute.attribute("stroke-width", "1.5"),
                    attribute.attribute("stroke", "currentColor"),
                    attribute.class("w-6 h-6"),
                  ],
                  [
                    svg.path([
                      attribute.attribute("stroke-linecap", "round"),
                      attribute.attribute("stroke-linejoin", "round"),
                      attribute.attribute(
                        "d",
                        "M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5",
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn view_messages(messages: List(Message)) -> Element(Msg) {
  html.div(
    [],
    messages
      |> list.map(view_message)
      |> list.reverse,
  )
}

fn view_message(message: Message) -> Element(Msg) {
  case message.from {
    User ->
      html.div([attribute.class("chat chat-end mb-2")], [
        html.div([attribute.class("chat-bubble chat-bubble-primary")], [
          element.text(message.text),
        ]),
      ])
    Server ->
      html.div([attribute.class("chat chat-start mb-2")], [
        html.div([attribute.class("chat-bubble chat-bubble-secondary")], [
          element.text(message.text),
        ]),
      ])
  }
}

// Helper to handle Enter key press
fn on_enter(msg: Msg) -> attribute.Attribute(Msg) {
  let decoder = {
    use key <- decode.field("key", decode.string)
    case key {
      "Enter" -> decode.success(msg)
      _ -> decode.failure(msg, key)
    }
  }
  event.on("keypress", decoder)
}

// COMPONENT -------------------------------------------------------------------

pub fn register() -> Result(Nil, lustre.Error) {
  let app = lustre.component(init, update, view, [])

  lustre.register(app, "lustre-chat")
}
