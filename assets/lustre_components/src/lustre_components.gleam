import components/chat
import components/checkout
import components/counter

pub fn register() -> Nil {
  let _ = counter.register()
  let _ = chat.register()
  let _ = checkout.register()
  Nil
}
