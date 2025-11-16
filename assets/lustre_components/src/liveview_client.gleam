/// Module for communicating with Phoenix LiveView from Lustre components
/// Provides a generic way to push events and receive replies without
/// requiring component-specific FFI modules.
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

@external(javascript, "./liveview_client_ffi.mjs", "push_event")
fn do_push_event(
  element_selector: String,
  event_name: String,
  payload: payload,
  on_reply: Option(fn(reply) -> msg),
) -> Effect(msg)
