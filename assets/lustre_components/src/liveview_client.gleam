/// Module for communicating with Phoenix LiveView from Lustre components
/// Provides a generic way to push events and receive replies without
/// requiring component-specific FFI modules.
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}
import lustre/effect.{type Effect}

/// Push an event to LiveView and optionally receive a reply
///
/// ## Example
///
/// ```gleam
/// // Send a message and handle the reply
/// push_event("lustre-chat", "chat-message", payload, Some(fn(reply) {
///   ReceiveReply(reply)
/// }))
/// ```
pub fn push_event(
  element_selector: String,
  event_name: String,
  payload: payload,
  on_reply: Option(fn(reply) -> msg),
) -> Effect(msg) {
  do_push_event(element_selector, event_name, payload, on_reply)
}

/// Subscribe to server-initiated events from LiveView
///
/// ## Example
///
/// ```gleam
/// // Listen for server-message events
/// subscribe_to_event("server-message", fn(detail) {
///   decode.run(detail, decode.field("message", decode.string))
///   |> result.map(ServerMessage)
///   |> result.unwrap(NoOp)
/// })
/// ```
pub fn subscribe_to_event(
  event_name: String,
  handler: fn(Dynamic) -> msg,
) -> Effect(msg) {
  do_subscribe_to_event(event_name, handler)
}

@external(javascript, "./liveview_client_ffi.mjs", "push_event")
fn do_push_event(
  element_selector: String,
  event_name: String,
  payload: payload,
  on_reply: Option(fn(reply) -> msg),
) -> Effect(msg)

@external(javascript, "./liveview_client_ffi.mjs", "subscribe_to_event")
fn do_subscribe_to_event(
  event_name: String,
  handler: fn(Dynamic) -> msg,
) -> Effect(msg)
