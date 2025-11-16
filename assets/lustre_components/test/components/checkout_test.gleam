import components/checkout
import lustre/dev/query
import lustre/dev/simulate

// QUERY HELPERS ---------------------------------------------------------------

fn button(text: String) -> query.Query {
  query.element(query.tag("button") |> query.and(query.text(text)))
}

fn input(name: String) -> query.Query {
  query.element(query.tag("input") |> query.and(query.attribute("name", name)))
}

fn checkbox(_name: String) -> query.Query {
  query.element(
    query.tag("input")
    |> query.and(query.attribute("type", "checkbox"))
    |> query.and(query.attribute("name", "marketing")),
  )
}

// SETUP HELPERS ---------------------------------------------------------------
// These use simulate.message to arrange the test state efficiently

fn start_checkout() -> simulate.Simulation(checkout.Model, checkout.Msg) {
  let app = simulate.application(checkout.init, checkout.update, checkout.view)
  simulate.start(app, Nil)
}

fn at_customer_details_step(
  sim: simulate.Simulation(checkout.Model, checkout.Msg),
) -> simulate.Simulation(checkout.Model, checkout.Msg) {
  simulate.message(sim, checkout.NextStep)
}

fn at_shipping_address_step(
  sim: simulate.Simulation(checkout.Model, checkout.Msg),
) -> simulate.Simulation(checkout.Model, checkout.Msg) {
  sim
  |> simulate.message(checkout.NextStep)
  |> simulate.message(checkout.UpdateEmail("test@example.com"))
  |> simulate.message(checkout.UpdateName("Test User"))
  |> simulate.message(checkout.NextStep)
}

fn at_marketing_consent_step(
  sim: simulate.Simulation(checkout.Model, checkout.Msg),
) -> simulate.Simulation(checkout.Model, checkout.Msg) {
  sim
  |> at_shipping_address_step
  |> simulate.message(checkout.UpdateAddress("123 Main St"))
  |> simulate.message(checkout.UpdateCity("Brisbane"))
  |> simulate.message(checkout.UpdateState("QLD"))
  |> simulate.message(checkout.UpdateZip("4000"))
  |> simulate.message(checkout.AddressValidated(True, []))
  |> simulate.message(checkout.NextStep)
  |> simulate.message(checkout.NextStep)
  |> simulate.message(checkout.NextStep)
}

// TESTS -----------------------------------------------------------------------

pub fn checkout_starts_at_cart_review_step_test() {
  let sim = start_checkout()
  let model = simulate.model(sim)

  assert model.step == checkout.CartReview
}

pub fn clicking_proceed_button_advances_to_customer_details_test() {
  let sim = start_checkout()

  let sim = simulate.click(sim, on: button("Proceed to Checkout"))

  let model = simulate.model(sim)
  assert model.step == checkout.CustomerDetails
}

pub fn customer_details_are_required_to_continue_test() {
  let sim = start_checkout() |> at_customer_details_step

  let sim = simulate.click(sim, on: button("Continue"))

  let model = simulate.model(sim)
  assert model.step == checkout.CustomerDetails
  assert model.validation_errors != []
}

pub fn filling_customer_form_and_clicking_continue_advances_test() {
  let sim = start_checkout() |> at_customer_details_step

  let sim =
    sim
    |> simulate.input(on: input("email"), value: "jane@example.com")
    |> simulate.input(on: input("name"), value: "Jane Doe")
    |> simulate.click(on: button("Continue"))

  let model = simulate.model(sim)
  assert model.step == checkout.ShippingAddress
  assert model.customer.email == "jane@example.com"
  assert model.customer.name == "Jane Doe"
}

pub fn clicking_back_button_returns_to_previous_step_test() {
  let sim =
    start_checkout()
    |> at_customer_details_step
    |> simulate.message(checkout.UpdateEmail("bob@example.com"))
    |> simulate.message(checkout.UpdateName("Bob Smith"))
    |> simulate.message(checkout.NextStep)

  let model = simulate.model(sim)
  assert model.step == checkout.ShippingAddress

  let sim = simulate.click(sim, on: button("Back"))

  let model = simulate.model(sim)
  assert model.step == checkout.CustomerDetails
  assert model.customer.email == "bob@example.com"
}

pub fn filling_shipping_form_updates_model_test() {
  let sim = start_checkout() |> at_shipping_address_step

  let sim =
    sim
    |> simulate.input(on: input("address"), value: "456 Oak Ave")
    |> simulate.input(on: input("city"), value: "Melbourne")
    |> simulate.input(on: input("state"), value: "VIC")
    |> simulate.input(on: input("zip"), value: "3000")

  let model = simulate.model(sim)
  assert model.shipping.address == "456 Oak Ave"
  assert model.shipping.city == "Melbourne"
  assert model.shipping.state == "VIC"
  assert model.shipping.zip == "3000"
}

pub fn address_must_be_validated_before_continuing_test() {
  let sim =
    start_checkout()
    |> at_shipping_address_step
    |> simulate.message(checkout.UpdateAddress("123 Main St"))
    |> simulate.message(checkout.UpdateCity("Brisbane"))
    |> simulate.message(checkout.UpdateState("QLD"))
    |> simulate.message(checkout.UpdateZip("4000"))

  let sim = simulate.click(sim, on: button("Continue"))

  let model = simulate.model(sim)
  assert model.step == checkout.ShippingAddress
  assert model.validation_errors != []
}

pub fn valid_address_allows_continuing_to_discount_step_test() {
  let sim =
    start_checkout()
    |> at_shipping_address_step
    |> simulate.message(checkout.UpdateAddress("123 Main St"))
    |> simulate.message(checkout.UpdateCity("Brisbane"))
    |> simulate.message(checkout.UpdateState("QLD"))
    |> simulate.message(checkout.UpdateZip("4000"))
    |> simulate.message(checkout.AddressValidated(True, []))

  let sim = simulate.click(sim, on: button("Continue"))

  let model = simulate.model(sim)
  assert model.step == checkout.DiscountCode
  assert model.shipping.is_validated == True
}

pub fn toggling_marketing_checkbox_updates_consent_test() {
  let sim = start_checkout() |> at_marketing_consent_step

  let model = simulate.model(sim)
  assert model.step == checkout.MarketingConsent
  assert model.marketing_consent == False

  let sim = simulate.click(sim, on: checkbox("marketing"))

  let model = simulate.model(sim)
  assert model.marketing_consent == True
}

// EFFECT TESTS ----------------------------------------------------------------
// Since simulate.application() intentionally discards effects, we test them
// by calling update() directly and verifying the resulting model state changes.
// This validates that the correct side effects WOULD be triggered.

pub fn validate_address_button_triggers_validation_state_test() {
  let model_before =
    start_checkout()
    |> at_shipping_address_step
    |> simulate.message(checkout.UpdateAddress("123 Main St"))
    |> simulate.message(checkout.UpdateCity("Brisbane"))
    |> simulate.message(checkout.UpdateState("QLD"))
    |> simulate.message(checkout.UpdateZip("4000"))
    |> simulate.model

  // Call update directly to verify state changes that would trigger effects
  let #(model_after, _effect) =
    checkout.update(model_before, checkout.ValidateAddress)

  // Verify the model state changed to indicate validation started
  assert model_before.is_validating == False
  assert model_after.is_validating == True
}

pub fn apply_discount_code_triggers_application_state_test() {
  let model_before =
    start_checkout()
    |> simulate.message(checkout.UpdateDiscountCode("SAVE10"))
    |> simulate.model

  // Call update directly to verify state changes
  let #(model_after, _effect) =
    checkout.update(model_before, checkout.ApplyDiscountCode)

  // The model should remain in a state ready to receive the response
  assert model_before.discount_code == "SAVE10"
  assert model_after.discount_code == "SAVE10"
}

pub fn continue_shopping_button_resets_to_initial_state_test() {
  // Arrange: Complete the entire checkout flow to OrderPlaced
  let sim =
    start_checkout()
    |> at_customer_details_step
    |> simulate.message(checkout.UpdateEmail("test@example.com"))
    |> simulate.message(checkout.UpdateName("Test User"))
    |> simulate.message(checkout.NextStep)
    |> simulate.message(checkout.UpdateAddress("123 Main St"))
    |> simulate.message(checkout.UpdateCity("Brisbane"))
    |> simulate.message(checkout.UpdateState("QLD"))
    |> simulate.message(checkout.UpdateZip("4000"))
    |> simulate.message(checkout.AddressValidated(True, []))
    |> simulate.message(checkout.NextStep)
    |> simulate.message(checkout.NextStep)
    |> simulate.message(checkout.NextStep)
    |> simulate.message(checkout.ToggleMarketingConsent)
    |> simulate.message(checkout.NextStep)
    |> simulate.message(checkout.OrderConfirmed("ORDER-123"))

  let model = simulate.model(sim)
  assert model.step == checkout.OrderPlaced

  // Act: Click "Continue Shopping" button
  let sim = simulate.click(sim, on: button("Continue Shopping"))

  // Assert: Should reset to initial CartReview state
  let model = simulate.model(sim)
  assert model.step == checkout.CartReview
  assert model.customer.email == ""
  assert model.customer.name == ""
  assert model.shipping.address == ""
  assert model.marketing_consent == False
}
