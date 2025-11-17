import { Option$isSome, Option$Some$0 } from "../gleam_stdlib/gleam/option.mjs";
import { from } from "../lustre/lustre/effect.mjs";

export function subscribe_to_event(event_name, handler) {
  return from((dispatch) => {
    const phx_event_name = `phx:${event_name}`;

    const event_handler = (event) => {
      const msg = handler(event.detail);
      dispatch(msg);
    };

    window.addEventListener(phx_event_name, event_handler);

    // Return cleanup function
    return () => {
      window.removeEventListener(phx_event_name, event_handler);
    };
  });
}

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

    // Use LiveView's pushEvent which handles the full event lifecycle
    // type is set to "push" for programmatic events (not DOM events like "click")
    view.pushEvent(
      "push",
      element,
      null,
      event_name,
      {},
      { value: payload },
      (reply) => {
        // If a callback was provided, use it
        if (Option$isSome(on_reply)) {
          const callback = Option$Some$0(on_reply);
          dispatch(callback(reply));
        }
      },
    );
  });
}
