import { Option$isSome, Option$Some$0 } from "../gleam_stdlib/gleam/option.mjs";
import { from } from "../lustre/lustre/effect.mjs";

export function push_event(element_selector, event_name, payload, on_reply) {
  return from((dispatch) => {
    // Find the element by selector
    const element = document.querySelector(element_selector);

    if (!element) {
      console.warn(
        `liveview_client: No element found with selector "${element_selector}"`,
      );
      return;
    }

    // Find the nearest LiveView
    let current = element;
    let view = null;

    while (current && current !== document) {
      view = window.liveSocket?.getViewByEl(current);
      if (view) break;
      current = current.parentElement;
    }

    if (!view) {
      console.warn(
        `liveview_client: No LiveView found for element "${element_selector}"`,
      );
      return;
    }

    // Send event directly to LiveView channel
    view.channel
      .push("event", {
        type: "event",
        event: event_name,
        value: payload,
      })
      .receive("ok", (reply) => {
        // If a callback was provided, use it
        if (Option$isSome(on_reply)) {
          const callback = Option$Some$0(on_reply);
          // LiveView wraps replies in {diff: {r: actualReply}}
          const actualReply = reply?.diff?.r || reply;
          dispatch(callback(actualReply));
        }
      });
  });
}
