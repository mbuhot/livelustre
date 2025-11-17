import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import liveview_client
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

// TYPES -----------------------------------------------------------------------

pub type Model {
  Model(
    step: Step,
    cart_items: List(CartItem),
    customer: CustomerInfo,
    shipping: ShippingInfo,
    discount_code: String,
    applied_discount: Option(Discount),
    discount_invalid: Bool,
    special_offers: List(SpecialOffer),
    is_validating: Bool,
    validation_errors: List(ValidationError),
    marketing_consent: Bool,
  )
}

pub type ValidationError {
  ValidationError(field: String, message: String)
}

pub type Step {
  CartReview
  CustomerDetails
  ShippingAddress
  DiscountCode
  OrderReview
  MarketingConsent
  OrderPlaced
}

pub type CartItem {
  CartItem(id: String, name: String, price: Int, quantity: Int)
}

pub type CustomerInfo {
  CustomerInfo(email: String, name: String)
}

pub type ShippingInfo {
  ShippingInfo(
    address: String,
    city: String,
    state: String,
    zip: String,
    is_validated: Bool,
  )
}

pub type Discount {
  Discount(code: String, amount: Int, description: String)
}

pub type SpecialOffer {
  SpecialOffer(title: String, description: String)
}

pub type Msg {
  NextStep
  PreviousStep
  ResetCheckout
  UpdateEmail(String)
  UpdateName(String)
  UpdateAddress(String)
  UpdateCity(String)
  UpdateState(String)
  UpdateZip(String)
  ValidateAddress
  AddressValidated(Bool, List(ValidationError))
  UpdateDiscountCode(String)
  ApplyDiscountCode
  DiscountApplied(Option(Discount))
  DiscountInvalid
  CheckSpecialOffers
  SpecialOffersReceived(List(SpecialOffer))
  ToggleMarketingConsent
  PlaceOrder
  OrderConfirmed(String)
}

// INIT ------------------------------------------------------------------------

pub fn init(_flags: Nil) -> #(Model, Effect(Msg)) {
  let cart_items = [
    CartItem(id: "1", name: "Gleam Book", price: 4999, quantity: 1),
    CartItem(id: "2", name: "Lustre Sticker Pack", price: 999, quantity: 2),
  ]

  let default_model =
    Model(
      step: CartReview,
      cart_items: cart_items,
      customer: CustomerInfo(email: "", name: ""),
      shipping: ShippingInfo(
        address: "",
        city: "",
        state: "",
        zip: "",
        is_validated: False,
      ),
      discount_code: "",
      applied_discount: None,
      discount_invalid: False,
      special_offers: [],
      is_validating: False,
      validation_errors: [],
      marketing_consent: False,
    )

  // Try to restore from localStorage and URL
  let model = restore_state(default_model)

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    NextStep -> {
      // Validate current step before proceeding
      let errors = validate_current_step(model)

      case errors {
        [] -> {
          // No errors, proceed to next step
          let next_step = case model.step {
            CartReview -> CustomerDetails
            CustomerDetails -> ShippingAddress
            ShippingAddress -> DiscountCode
            DiscountCode -> OrderReview
            OrderReview -> MarketingConsent
            MarketingConsent -> OrderPlaced
            OrderPlaced -> OrderPlaced
          }

          let new_model = Model(..model, step: next_step, validation_errors: [])

          // Focus the first input of the next step
          let focus_selector = case next_step {
            CustomerDetails -> "#customer-email"
            ShippingAddress -> "#shipping-address"
            _ -> ""
          }

          let focus_eff = case focus_selector {
            "" -> effect.none()
            selector -> focus_effect(selector)
          }

          // Combine effects: save state, update URL, and focus
          let save_eff = save_state_effect(new_model)
          let url_eff = update_url_effect(next_step)

          let combined_eff = effect.batch([focus_eff, save_eff, url_eff])

          #(new_model, combined_eff)
        }
        _ -> {
          // Show validation errors
          #(Model(..model, validation_errors: errors), effect.none())
        }
      }
    }

    PreviousStep -> {
      let prev_step = case model.step {
        CustomerDetails -> CartReview
        ShippingAddress -> CustomerDetails
        DiscountCode -> ShippingAddress
        OrderReview -> DiscountCode
        MarketingConsent -> OrderReview
        _ -> model.step
      }

      let new_model = Model(..model, step: prev_step)

      // Update URL and save state
      let save_eff = save_state_effect(new_model)
      let url_eff = update_url_effect(prev_step)
      let combined_eff = effect.batch([save_eff, url_eff])

      #(new_model, combined_eff)
    }

    ResetCheckout -> {
      // Reset to initial state
      let #(initial_model, _) = init(Nil)

      // Update URL and clear saved state
      let save_eff = save_state_effect(initial_model)
      let url_eff = update_url_effect(CartReview)
      let combined_eff = effect.batch([save_eff, url_eff])

      #(initial_model, combined_eff)
    }

    UpdateEmail(email) -> {
      let customer = CustomerInfo(..model.customer, email: email)
      #(Model(..model, customer: customer), effect.none())
    }

    UpdateName(name) -> {
      let customer = CustomerInfo(..model.customer, name: name)
      #(Model(..model, customer: customer), effect.none())
    }

    UpdateAddress(address) -> {
      let shipping =
        ShippingInfo(..model.shipping, address: address, is_validated: False)
      #(Model(..model, shipping: shipping), effect.none())
    }

    UpdateCity(city) -> {
      let shipping =
        ShippingInfo(..model.shipping, city: city, is_validated: False)
      #(Model(..model, shipping: shipping), effect.none())
    }

    UpdateState(state) -> {
      let shipping =
        ShippingInfo(..model.shipping, state: state, is_validated: False)
      #(Model(..model, shipping: shipping), effect.none())
    }

    UpdateZip(zip) -> {
      let shipping =
        ShippingInfo(..model.shipping, zip: zip, is_validated: False)
      #(Model(..model, shipping: shipping), effect.none())
    }

    ValidateAddress -> {
      let payload =
        json.object([
          #("address", json.string(model.shipping.address)),
          #("city", json.string(model.shipping.city)),
          #("state", json.string(model.shipping.state)),
          #("zip", json.string(model.shipping.zip)),
        ])

      let eff =
        liveview_client.push_event(
          "lustre-checkout",
          "validate-address",
          payload,
          Some(fn(reply) {
            // Parse the reply to get validation result and errors
            parse_validation_reply(reply)
          }),
        )

      #(Model(..model, is_validating: True), eff)
    }

    AddressValidated(is_valid, errors) -> {
      let shipping = ShippingInfo(..model.shipping, is_validated: is_valid)
      let focus_eff = case is_valid {
        True -> focus_effect("#shipping-continue")
        False -> effect.none()
      }
      #(
        Model(
          ..model,
          shipping: shipping,
          is_validating: False,
          validation_errors: errors,
        ),
        focus_eff,
      )
    }

    UpdateDiscountCode(code) -> #(
      Model(..model, discount_code: code, discount_invalid: False),
      effect.none(),
    )

    ApplyDiscountCode -> {
      let payload = json.object([#("code", json.string(model.discount_code))])

      let eff =
        liveview_client.push_event(
          "lustre-checkout",
          "apply-discount",
          payload,
          Some(parse_discount_reply),
        )

      #(model, eff)
    }

    DiscountApplied(discount) -> #(
      Model(..model, applied_discount: discount, discount_invalid: False),
      effect.none(),
    )

    DiscountInvalid -> #(
      Model(..model, applied_discount: None, discount_invalid: True),
      effect.none(),
    )

    CheckSpecialOffers -> {
      let item_ids = list.map(model.cart_items, fn(item) { item.id })
      let payload =
        json.object([
          #("item_ids", json.array(item_ids, fn(id) { json.string(id) })),
        ])

      let eff =
        liveview_client.push_event(
          "lustre-checkout",
          "check-special-offers",
          payload,
          Some(fn(_result) {
            // TODO: Parse offers
            SpecialOffersReceived([])
          }),
        )

      #(model, eff)
    }

    SpecialOffersReceived(offers) -> #(
      Model(..model, special_offers: offers),
      effect.none(),
    )

    ToggleMarketingConsent -> #(
      Model(..model, marketing_consent: !model.marketing_consent),
      effect.none(),
    )

    PlaceOrder -> {
      let payload =
        json.object([
          #("customer_email", json.string(model.customer.email)),
          #("customer_name", json.string(model.customer.name)),
          #("shipping_address", json.string(model.shipping.address)),
          #("shipping_city", json.string(model.shipping.city)),
          #("shipping_state", json.string(model.shipping.state)),
          #("shipping_zip", json.string(model.shipping.zip)),
          #("discount_code", json.string(model.discount_code)),
          #("marketing_consent", json.bool(model.marketing_consent)),
        ])

      let eff =
        liveview_client.push_event(
          "lustre-checkout",
          "place-order",
          payload,
          Some(OrderConfirmed),
        )

      #(model, eff)
    }

    OrderConfirmed(_order_id) -> {
      // Clear saved state from localStorage when order is successfully placed
      let clear_effect = clear_local_storage_effect()
      #(Model(..model, step: OrderPlaced), clear_effect)
    }
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("container mx-auto max-w-4xl mt-8 px-4")], [
    html.h1([attribute.class("text-4xl font-bold mb-8 text-center")], [
      element.text("🛒 Checkout"),
    ]),
    view_progress(model.step),
    html.div([attribute.class("card bg-base-200 shadow-xl mt-8")], [
      html.div([attribute.class("card-body")], [view_step(model)]),
    ]),
  ])
}

fn view_progress(step: Step) -> Element(Msg) {
  let steps = [
    #("Cart", CartReview),
    #("Customer", CustomerDetails),
    #("Shipping", ShippingAddress),
    #("Discount", DiscountCode),
    #("Review", OrderReview),
    #("Complete", OrderPlaced),
  ]

  html.ul([attribute.class("steps steps-horizontal w-full")], {
    list.map(steps, fn(item) {
      let #(label, item_step) = item
      let is_active = step == item_step
      let is_complete = step_number(step) > step_number(item_step)

      let class = case is_complete, is_active {
        True, _ -> "step step-primary"
        _, True -> "step step-primary"
        _, _ -> "step"
      }

      html.li([attribute.class(class)], [element.text(label)])
    })
  })
}

fn step_number(step: Step) -> Int {
  case step {
    CartReview -> 0
    CustomerDetails -> 1
    ShippingAddress -> 2
    DiscountCode -> 3
    OrderReview -> 4
    MarketingConsent -> 5
    OrderPlaced -> 6
  }
}

fn view_step(model: Model) -> Element(Msg) {
  case model.step {
    CartReview -> view_cart_review(model)
    CustomerDetails -> view_customer_details(model)
    ShippingAddress -> view_shipping_address(model)
    DiscountCode -> view_discount_code(model)
    OrderReview -> view_order_review(model)
    MarketingConsent -> view_marketing_consent(model)
    OrderPlaced -> view_order_placed(model)
  }
}

fn view_cart_review(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Your Cart"),
    ]),
    html.div([attribute.class("space-y-4")], {
      list.map(model.cart_items, view_cart_item)
    }),
    html.div([attribute.class("divider")], []),
    html.div([attribute.class("text-right text-xl font-bold")], [
      element.text("Total: $" <> format_price(calculate_total(model))),
    ]),
    html.div([attribute.class("card-actions justify-end mt-6")], [
      html.button(
        [attribute.class("btn btn-primary"), event.on_click(NextStep)],
        [element.text("Proceed to Checkout")],
      ),
    ]),
  ])
}

fn view_cart_item(item: CartItem) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "flex justify-between items-center p-4 bg-base-200 rounded-lg",
      ),
    ],
    [
      html.div([], [
        html.div([attribute.class("font-bold")], [element.text(item.name)]),
        html.div([attribute.class("text-sm opacity-70")], [
          element.text("Quantity: " <> int.to_string(item.quantity)),
        ]),
      ]),
      html.div([attribute.class("text-lg font-bold")], [
        element.text("$" <> format_price(item.price * item.quantity)),
      ]),
    ],
  )
}

fn view_customer_details(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Customer Details"),
    ]),
    html.div([attribute.class("form-control mb-6")], [
      html.label([attribute.class("label pb-2")], [
        html.span([attribute.class("label-text font-semibold")], [
          element.text("Email"),
        ]),
      ]),
      html.input([
        attribute.id("customer-email"),
        attribute.name("email"),
        attribute.type_("email"),
        attribute.class("input input-bordered w-full bg-white dark:bg-base-300"),
        attribute.value(model.customer.email),
        event.on_input(UpdateEmail),
      ]),
      view_field_error(model.validation_errors, "email"),
    ]),
    html.div([attribute.class("form-control mb-6")], [
      html.label([attribute.class("label pb-2")], [
        html.span([attribute.class("label-text font-semibold")], [
          element.text("Full Name"),
        ]),
      ]),
      html.input([
        attribute.name("name"),
        attribute.type_("text"),
        attribute.class("input input-bordered w-full bg-white dark:bg-base-300"),
        attribute.value(model.customer.name),
        event.on_input(UpdateName),
      ]),
      view_field_error(model.validation_errors, "name"),
    ]),
    html.div([attribute.class("card-actions justify-between mt-6")], [
      html.button(
        [attribute.class("btn btn-ghost"), event.on_click(PreviousStep)],
        [element.text("Back")],
      ),
      html.button(
        [attribute.class("btn btn-primary"), event.on_click(NextStep)],
        [element.text("Continue")],
      ),
    ]),
  ])
}

fn view_shipping_address(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Shipping Address"),
    ]),
    html.div([attribute.class("form-control mb-6")], [
      html.label([attribute.class("label pb-2")], [
        html.span([attribute.class("label-text font-semibold")], [
          element.text("Street Address"),
        ]),
      ]),
      html.input([
        attribute.id("shipping-address"),
        attribute.name("address"),
        attribute.type_("text"),
        attribute.class("input input-bordered w-full bg-white dark:bg-base-300"),
        attribute.value(model.shipping.address),
        event.on_input(UpdateAddress),
      ]),
      view_field_error(model.validation_errors, "address"),
    ]),
    html.div([attribute.class("grid grid-cols-2 gap-4 mb-6")], [
      html.div([attribute.class("form-control")], [
        html.label([attribute.class("label pb-2")], [
          html.span([attribute.class("label-text font-semibold")], [
            element.text("City"),
          ]),
        ]),
        html.input([
          attribute.name("city"),
          attribute.type_("text"),
          attribute.class(
            "input input-bordered w-full bg-white dark:bg-base-300",
          ),
          attribute.value(model.shipping.city),
          event.on_input(UpdateCity),
        ]),
        view_field_error(model.validation_errors, "city"),
      ]),
      html.div([attribute.class("form-control")], [
        html.label([attribute.class("label pb-2")], [
          html.span([attribute.class("label-text font-semibold")], [
            element.text("State"),
          ]),
        ]),
        html.input([
          attribute.name("state"),
          attribute.type_("text"),
          attribute.class(
            "input input-bordered w-full bg-white dark:bg-base-300",
          ),
          attribute.value(model.shipping.state),
          event.on_input(UpdateState),
        ]),
        view_field_error(model.validation_errors, "state"),
      ]),
    ]),
    html.div([attribute.class("form-control mb-6")], [
      html.label([attribute.class("label pb-2")], [
        html.span([attribute.class("label-text font-semibold")], [
          element.text("Post Code"),
        ]),
      ]),
      html.input([
        attribute.name("zip"),
        attribute.type_("text"),
        attribute.class("input input-bordered w-full bg-white dark:bg-base-300"),
        attribute.value(model.shipping.zip),
        event.on_input(UpdateZip),
      ]),
      view_field_error(model.validation_errors, "zip"),
    ]),
    case model.is_validating, model.shipping.is_validated {
      True, _ ->
        html.button(
          [
            attribute.class("btn btn-outline mb-4"),
            attribute.disabled(True),
          ],
          [element.text("Validating...")],
        )
      False, True ->
        html.div([attribute.class("alert alert-success mb-4")], [
          element.text("✅ Shipping is available to your location"),
        ])
      False, False ->
        html.div([attribute.class("space-y-4 mb-4")], [
          case list.is_empty(model.validation_errors) {
            True ->
              html.button(
                [
                  attribute.class("btn btn-outline"),
                  event.on_click(ValidateAddress),
                ],
                [element.text("Validate Address")],
              )
            False ->
              html.div([], [
                html.div([attribute.class("alert alert-error mb-2")], [
                  element.text(
                    "❌ Unable to validate address. Please check the details and try again.",
                  ),
                ]),
                html.button(
                  [
                    attribute.class("btn btn-outline"),
                    event.on_click(ValidateAddress),
                  ],
                  [element.text("Retry Validation")],
                ),
              ])
          },
        ])
    },
    html.div([attribute.class("card-actions justify-between mt-6")], [
      html.button(
        [attribute.class("btn btn-ghost"), event.on_click(PreviousStep)],
        [element.text("Back")],
      ),
      html.button(
        [
          attribute.id("shipping-continue"),
          attribute.class("btn btn-primary"),
          event.on_click(NextStep),
        ],
        [element.text("Continue")],
      ),
    ]),
  ])
}

fn view_discount_code(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Discount Code"),
    ]),
    html.div([attribute.class("join w-full mb-4")], [
      html.input([
        attribute.type_("text"),
        attribute.class("input input-bordered join-item flex-1"),
        attribute.placeholder("Enter discount code"),
        attribute.value(model.discount_code),
        event.on_input(UpdateDiscountCode),
      ]),
      html.button(
        [
          attribute.class("btn btn-primary join-item"),
          event.on_click(ApplyDiscountCode),
        ],
        [element.text("Apply")],
      ),
    ]),
    case model.applied_discount, model.discount_invalid {
      Some(discount), _ ->
        html.div([attribute.class("alert alert-success mb-4")], [
          element.text(
            "✓ "
            <> discount.description
            <> " - $"
            <> format_price(discount.amount)
            <> " off",
          ),
        ])
      None, True ->
        html.div([attribute.class("alert alert-error mb-4")], [
          element.text("❌ Invalid discount code"),
        ])
      None, False -> html.div([], [])
    },
    html.div([attribute.class("card-actions justify-between mt-6")], [
      html.button(
        [attribute.class("btn btn-ghost"), event.on_click(PreviousStep)],
        [element.text("Back")],
      ),
      html.button(
        [attribute.class("btn btn-primary"), event.on_click(NextStep)],
        [element.text("Continue")],
      ),
    ]),
  ])
}

fn view_order_review(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Order Review"),
    ]),
    html.div([attribute.class("space-y-4 mb-6")], [
      html.div([attribute.class("card bg-base-200")], [
        html.div([attribute.class("card-body")], [
          html.h3([attribute.class("card-title")], [element.text("Customer")]),
          html.p([], [element.text(model.customer.name)]),
          html.p([], [element.text(model.customer.email)]),
        ]),
      ]),
      html.div([attribute.class("card bg-base-200")], [
        html.div([attribute.class("card-body")], [
          html.h3([attribute.class("card-title")], [
            element.text("Shipping Address"),
          ]),
          html.p([], [element.text(model.shipping.address)]),
          html.p([], [
            element.text(
              model.shipping.city
              <> ", "
              <> model.shipping.state
              <> " "
              <> model.shipping.zip,
            ),
          ]),
        ]),
      ]),
      html.div([attribute.class("card bg-base-200")], [
        html.div([attribute.class("card-body")], [
          html.h3([attribute.class("card-title")], [element.text("Items")]),
          html.div([attribute.class("space-y-2")], {
            list.map(model.cart_items, fn(item) {
              html.div([attribute.class("flex justify-between")], [
                html.span([], [element.text(item.name)]),
                html.span([], [
                  element.text("$" <> format_price(item.price * item.quantity)),
                ]),
              ])
            })
          }),
          html.div([attribute.class("divider")], []),
          html.div([attribute.class("flex justify-between text-xl font-bold")], [
            html.span([], [element.text("Total:")]),
            html.span([], [
              element.text("$" <> format_price(calculate_total(model))),
            ]),
          ]),
        ]),
      ]),
    ]),
    html.div([attribute.class("card-actions justify-between mt-6")], [
      html.button(
        [attribute.class("btn btn-ghost"), event.on_click(PreviousStep)],
        [element.text("Back")],
      ),
      html.button(
        [attribute.class("btn btn-primary"), event.on_click(NextStep)],
        [element.text("Continue to Confirmation")],
      ),
    ]),
  ])
}

fn view_marketing_consent(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([attribute.class("text-2xl font-bold mb-4")], [
      element.text("Stay Updated!"),
    ]),
    html.p([attribute.class("mb-6")], [
      element.text(
        "Get exclusive deals and updates delivered to your inbox. No spam, we promise!",
      ),
    ]),
    html.div([attribute.class("form-control mb-6")], [
      html.label([attribute.class("label cursor-pointer justify-start gap-4")], [
        html.input([
          attribute.name("marketing"),
          attribute.type_("checkbox"),
          attribute.class("checkbox checkbox-primary"),
          attribute.checked(model.marketing_consent),
          event.on_click(ToggleMarketingConsent),
        ]),
        html.span([attribute.class("label-text text-lg")], [
          element.text(
            "Yes, I'd like to receive emails about special offers and new products",
          ),
        ]),
      ]),
    ]),
    html.div([attribute.class("card-actions justify-between mt-6")], [
      html.button(
        [attribute.class("btn btn-ghost"), event.on_click(PreviousStep)],
        [element.text("Back")],
      ),
      html.button(
        [attribute.class("btn btn-primary btn-lg"), event.on_click(PlaceOrder)],
        [element.text("Place Order")],
      ),
    ]),
  ])
}

fn view_order_placed(_model: Model) -> Element(Msg) {
  html.div([attribute.class("text-center py-12")], [
    html.div([attribute.class("text-6xl mb-4")], [element.text("🎉")]),
    html.h2([attribute.class("text-3xl font-bold mb-4")], [
      element.text("Order Placed Successfully!"),
    ]),
    html.p([attribute.class("text-lg mb-6")], [
      element.text(
        "Thank you for your order. You'll receive a confirmation email shortly.",
      ),
    ]),
    html.button(
      [attribute.class("btn btn-primary"), event.on_click(ResetCheckout)],
      [element.text("Continue Shopping")],
    ),
  ])
}

// VALIDATION ------------------------------------------------------------------

fn validate_current_step(model: Model) -> List(ValidationError) {
  case model.step {
    CartReview -> []
    CustomerDetails -> validate_customer_details(model.customer)
    ShippingAddress -> validate_shipping_address(model.shipping)
    DiscountCode -> []
    OrderReview -> []
    MarketingConsent -> []
    OrderPlaced -> []
  }
}

fn validate_customer_details(customer: CustomerInfo) -> List(ValidationError) {
  let errors = []

  let errors = case customer.email {
    "" -> [ValidationError("email", "Email is required"), ..errors]
    email ->
      case string.contains(email, "@") && string.contains(email, ".") {
        True -> errors
        False -> [
          ValidationError("email", "Please enter a valid email address"),
          ..errors
        ]
      }
  }

  let errors = case customer.name {
    "" -> [ValidationError("name", "Full name is required"), ..errors]
    _ -> errors
  }

  errors
}

fn validate_shipping_address(shipping: ShippingInfo) -> List(ValidationError) {
  let errors = []

  let errors = case shipping.address {
    "" -> [ValidationError("address", "Street address is required"), ..errors]
    _ -> errors
  }

  let errors = case shipping.city {
    "" -> [ValidationError("city", "City is required"), ..errors]
    _ -> errors
  }

  let errors = case shipping.state {
    "" -> [ValidationError("state", "State is required"), ..errors]
    _ -> errors
  }

  let errors = case shipping.zip {
    "" -> [ValidationError("zip", "Post code is required"), ..errors]
    zip ->
      case string.length(zip) == 4 {
        True -> errors
        False -> [
          ValidationError("zip", "Post code must be 4 digits"),
          ..errors
        ]
      }
  }

  // Require server-side validation
  let errors = case shipping.is_validated {
    False -> [
      ValidationError(
        "address",
        "Please validate the address before continuing",
      ),
      ..errors
    ]
    True -> errors
  }

  errors
}

fn get_error_for_field(
  errors: List(ValidationError),
  field: String,
) -> Option(String) {
  case list.find(errors, fn(error) { error.field == field }) {
    Ok(error) -> Some(error.message)
    Error(_) -> None
  }
}

fn view_field_error(
  errors: List(ValidationError),
  field: String,
) -> Element(Msg) {
  case get_error_for_field(errors, field) {
    Some(message) ->
      html.label([attribute.class("label")], [
        html.span([attribute.class("label-text-alt text-error")], [
          element.text(message),
        ]),
      ])
    None -> html.div([], [])
  }
}

// HELPERS ---------------------------------------------------------------------

fn calculate_total(model: Model) -> Int {
  let subtotal =
    list.fold(model.cart_items, 0, fn(acc, item) {
      acc + item.price * item.quantity
    })

  case model.applied_discount {
    Some(discount) -> subtotal - discount.amount
    None -> subtotal
  }
}

fn format_price(cents: Int) -> String {
  let dollars = cents / 100
  let remaining_cents = cents % 100
  int.to_string(dollars)
  <> "."
  <> case remaining_cents < 10 {
    True -> "0" <> int.to_string(remaining_cents)
    False -> int.to_string(remaining_cents)
  }
}

fn parse_discount_reply(reply: Dynamic) -> Msg {
  // Decode the discount response
  let decoder = {
    use valid <- decode.field("valid", decode.bool)
    case valid {
      True -> {
        use amount <- decode.field("amount", decode.int)
        use description <- decode.field("description", decode.string)
        decode.success(
          DiscountApplied(
            Some(Discount(code: "", amount: amount, description: description)),
          ),
        )
      }
      False -> decode.success(DiscountInvalid)
    }
  }

  case decode.run(reply, decoder) {
    Ok(msg) -> msg
    Error(_) -> DiscountInvalid
  }
}

fn parse_validation_reply(reply: Dynamic) -> Msg {
  // Decode the validation response
  let valid_decoder =
    decode.field("valid", decode.bool, fn(valid) {
      decode.optional_field(
        "errors",
        None,
        decode.optional(decode.dict(decode.string, decode.string)),
        fn(errors_opt) { decode.success(#(valid, errors_opt)) },
      )
    })

  case decode.run(reply, valid_decoder) {
    Ok(#(True, _)) -> AddressValidated(True, [])
    Ok(#(False, Some(errors_dict))) -> {
      // Convert dict to list of ValidationError
      let errors =
        errors_dict
        |> dict.to_list
        |> list.map(fn(pair) {
          let #(field, message) = pair
          ValidationError(field, message)
        })
      AddressValidated(False, errors)
    }
    Ok(#(False, None)) -> AddressValidated(False, [])
    Error(_decode_errors) ->
      AddressValidated(False, [
        ValidationError("address", "Failed to parse validation response"),
      ])
  }
}

// STATE PERSISTENCE -----------------------------------------------------------

fn step_to_string(step: Step) -> String {
  case step {
    CartReview -> "cart"
    CustomerDetails -> "customer"
    ShippingAddress -> "shipping"
    DiscountCode -> "discount"
    OrderReview -> "review"
    MarketingConsent -> "marketing"
    OrderPlaced -> "placed"
  }
}

fn string_to_step(str: String) -> Option(Step) {
  case str {
    "cart" -> Some(CartReview)
    "customer" -> Some(CustomerDetails)
    "shipping" -> Some(ShippingAddress)
    "discount" -> Some(DiscountCode)
    "review" -> Some(OrderReview)
    "marketing" -> Some(MarketingConsent)
    "placed" -> Some(OrderPlaced)
    _ -> None
  }
}

fn encode_model(model: Model) -> json.Json {
  json.object([
    #("step", json.string(step_to_string(model.step))),
    #("customer_email", json.string(model.customer.email)),
    #("customer_name", json.string(model.customer.name)),
    #("shipping_address", json.string(model.shipping.address)),
    #("shipping_city", json.string(model.shipping.city)),
    #("shipping_state", json.string(model.shipping.state)),
    #("shipping_zip", json.string(model.shipping.zip)),
    #("shipping_validated", json.bool(model.shipping.is_validated)),
    #("discount_code", json.string(model.discount_code)),
    #("applied_discount", case model.applied_discount {
      Some(discount) ->
        json.object([
          #("code", json.string(discount.code)),
          #("amount", json.int(discount.amount)),
          #("description", json.string(discount.description)),
        ])
      None -> json.null()
    }),
    #("marketing_consent", json.bool(model.marketing_consent)),
  ])
}

fn restore_state(default_model: Model) -> Model {
  // First check URL for step (safe to call, returns [] in non-browser environments)
  let tuple_decoder = {
    use key <- decode.field(0, decode.string)
    use value <- decode.field(1, decode.string)
    decode.success(#(key, value))
  }

  let url_step = case
    decode.run(do_get_url_params(), decode.list(tuple_decoder))
  {
    Ok(params) -> {
      list.find(params, fn(param: #(String, String)) { param.0 == "step" })
      |> result.map(fn(param: #(String, String)) { string_to_step(param.1) })
      |> result.unwrap(None)
    }
    Error(_) -> None
  }

  // Then load saved state from localStorage (safe to call, returns null in non-browser environments)
  let saved_state = do_load_from_local_storage("checkout_state")

  // Try to decode saved state
  let decoder = {
    use step <- decode.optional_field("step", "", decode.string)
    use customer_email <- decode.optional_field(
      "customer_email",
      "",
      decode.string,
    )
    use customer_name <- decode.optional_field(
      "customer_name",
      "",
      decode.string,
    )
    use shipping_address <- decode.optional_field(
      "shipping_address",
      "",
      decode.string,
    )
    use shipping_city <- decode.optional_field(
      "shipping_city",
      "",
      decode.string,
    )
    use shipping_state <- decode.optional_field(
      "shipping_state",
      "",
      decode.string,
    )
    use shipping_zip <- decode.optional_field("shipping_zip", "", decode.string)
    use shipping_validated <- decode.optional_field(
      "shipping_validated",
      False,
      decode.bool,
    )
    use discount_code <- decode.optional_field(
      "discount_code",
      "",
      decode.string,
    )
    use applied_discount_opt <- decode.optional_field(
      "applied_discount",
      None,
      decode.optional({
        use code <- decode.field("code", decode.string)
        use amount <- decode.field("amount", decode.int)
        use description <- decode.field("description", decode.string)
        decode.success(Discount(
          code: code,
          amount: amount,
          description: description,
        ))
      }),
    )
    use marketing_consent <- decode.optional_field(
      "marketing_consent",
      False,
      decode.bool,
    )

    let parsed_step = case string_to_step(step) {
      Some(s) -> s
      None -> default_model.step
    }

    // Override with URL step if present
    let final_step = case url_step {
      Some(s) -> s
      None -> parsed_step
    }

    decode.success(
      Model(
        ..default_model,
        step: final_step,
        customer: CustomerInfo(email: customer_email, name: customer_name),
        shipping: ShippingInfo(
          address: shipping_address,
          city: shipping_city,
          state: shipping_state,
          zip: shipping_zip,
          is_validated: shipping_validated,
        ),
        discount_code: discount_code,
        applied_discount: applied_discount_opt,
        marketing_consent: marketing_consent,
      ),
    )
  }

  case decode.run(saved_state, decoder) {
    Ok(model) -> model
    Error(_) -> {
      // Failed to decode, use default with URL step if available
      case url_step {
        Some(step) -> Model(..default_model, step: step)
        None -> default_model
      }
    }
  }
}

// EFFECTS ---------------------------------------------------------------------

fn focus_effect(selector: String) -> Effect(Msg) {
  use _dispatch, root <- effect.after_paint
  do_focus(root, selector)
}

fn save_state_effect(model: Model) -> Effect(Msg) {
  use _dispatch, _root <- effect.after_paint
  let state = encode_model(model)
  do_save_to_local_storage("checkout_state", state)
}

fn update_url_effect(step: Step) -> Effect(Msg) {
  use _dispatch, _root <- effect.after_paint
  let step_name = step_to_string(step)
  do_update_url_params([#("step", step_name)])
}

fn clear_local_storage_effect() -> Effect(Msg) {
  use _dispatch, _root <- effect.after_paint
  do_remove_from_local_storage("checkout_state")
}

@external(javascript, "../dom_ffi.mjs", "focus")
fn do_focus(root: Dynamic, selector: String) -> Nil

@external(javascript, "../dom_ffi.mjs", "saveToLocalStorage")
fn do_save_to_local_storage(key: String, value: json.Json) -> Nil

@external(javascript, "../dom_ffi.mjs", "updateUrlParams")
fn do_update_url_params(params: List(#(String, String))) -> Nil

@external(javascript, "../dom_ffi.mjs", "loadFromLocalStorage")
fn do_load_from_local_storage(key: String) -> Dynamic

@external(javascript, "../dom_ffi.mjs", "removeFromLocalStorage")
fn do_remove_from_local_storage(key: String) -> Nil

@external(javascript, "../dom_ffi.mjs", "getUrlParams")
fn do_get_url_params() -> Dynamic

// COMPONENT -------------------------------------------------------------------

pub fn register() -> Result(Nil, lustre.Error) {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "lustre-checkout")
}
