defmodule LivelustreWeb.CheckoutLive do
  use LivelustreWeb, :live_view

  alias Livelustre.Commerce

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <lustre-checkout id="lustre-checkout" phx-update="ignore"></lustre-checkout>
    """
  end

  @impl true
  def handle_event("validate-address", address, socket) do
    case Commerce.validate_address(address) do
      {:ok} ->
        {:reply, %{valid: true}, socket}

      {:error, errors} ->
        {:reply, %{valid: false, errors: errors}, socket}
    end
  end

  @impl true
  def handle_event("apply-discount", %{"code" => code}, socket) do
    discount = Commerce.lookup_discount_code(code)
    {:reply, discount, socket}
  end

  @impl true
  def handle_event("check-special-offers", %{"item_ids" => item_ids}, socket) do
    offers = Commerce.find_special_offers(item_ids)
    {:reply, %{offers: offers}, socket}
  end

  @impl true
  def handle_event("place-order", order_details, socket) do
    order_id = Commerce.generate_order_id()

    if order_details["marketing_consent"] do
      Commerce.subscribe_to_marketing(order_details["customer_email"])
    end

    {:reply, %{order_id: order_id, success: true}, socket}
  end
end
