defmodule Livelustre.Commerce do
  @moduledoc """
  Business logic for e-commerce operations including address validation,
  discount codes, and special offers.
  """

  @type validation_result :: {:ok} | {:error, %{String.t() => String.t()}}

  @doc """
  Validates an Australian address.

  Accepts a map with string keys from external input (e.g., JSON, form params).
  Returns `{:ok}` if valid, or `{:error, errors}` where errors is a map
  of field names to error messages.
  """
  @spec validate_address(%{String.t() => String.t()}) :: validation_result()
  def validate_address(%{
        "address" => address,
        "city" => city,
        "state" => state,
        "zip" => zip
      }) do
    %{}
    |> validate_address_field(address)
    |> validate_city_field(city)
    |> validate_state_field(state)
    |> validate_zip_field(zip)
    |> case do
      errors when errors == %{} -> {:ok}
      errors -> {:error, errors}
    end
  end

  def validate_address(_), do: {:error, %{"address" => "Invalid address format"}}

  defp validate_address_field(errors, address) do
    if address == "" do
      Map.put(errors, "address", "Street address is required")
    else
      errors
    end
  end

  defp validate_city_field(errors, city) do
    if city == "" do
      Map.put(errors, "city", "City is required")
    else
      errors
    end
  end

  defp validate_state_field(errors, state) do
    valid_states = ["QLD", "NSW", "VIC"]

    cond do
      state == "" ->
        Map.put(errors, "state", "State is required")

      String.upcase(state) not in valid_states ->
        Map.put(errors, "state", "State must be QLD, NSW, or VIC")

      true ->
        errors
    end
  end

  defp validate_zip_field(errors, zip) do
    cond do
      zip == "" -> Map.put(errors, "zip", "Post code is required")
      not String.match?(zip, ~r/^\d{4}$/) -> Map.put(errors, "zip", "Post code must be 4 digits")
      true -> errors
    end
  end

  @doc """
  Looks up a discount code and returns discount information.

  Returns a map with `:valid` set to `true` and discount details if valid,
  or a map with `:valid` set to `false` if invalid.
  """
  @spec lookup_discount_code(String.t()) ::
          %{valid: boolean(), amount: integer(), description: String.t()} | %{valid: false}
  def lookup_discount_code(code) do
    case String.upcase(code) do
      "SAVE10" -> %{valid: true, amount: 1000, description: "10% off"}
      "FREESHIP" -> %{valid: true, amount: 500, description: "Free shipping"}
      "GLEAM25" -> %{valid: true, amount: 2500, description: "25% off Gleam products"}
      _ -> %{valid: false}
    end
  end

  @doc """
  Finds special offers based on cart item IDs.

  Returns a list of special offer maps.
  """
  @spec find_special_offers(list(String.t())) ::
          list(%{title: String.t(), description: String.t()})
  def find_special_offers(item_ids) do
    cond do
      "1" in item_ids and "2" in item_ids ->
        [
          %{
            title: "Bundle Deal!",
            description: "Get 15% off when you buy a book and stickers together"
          }
        ]

      length(item_ids) >= 3 ->
        [
          %{
            title: "Volume Discount",
            description: "Buy 3 or more items and save 10%"
          }
        ]

      true ->
        []
    end
  end

  @doc """
  Generates a unique order ID.
  """
  @spec generate_order_id() :: String.t()
  def generate_order_id do
    "ORD-#{:rand.uniform(999_999) |> Integer.to_string() |> String.pad_leading(6, "0")}"
  end

  @doc """
  Subscribes an email address to marketing communications.

  In a real application, this would integrate with a mailing list service.
  For demo purposes, it logs the subscription.
  """
  @spec subscribe_to_marketing(String.t()) :: :ok
  def subscribe_to_marketing(email) do
    require Logger
    Logger.info("Subscribing #{email} to marketing emails")
    :ok
  end
end
