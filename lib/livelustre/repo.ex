defmodule Livelustre.Repo do
  use Ecto.Repo,
    otp_app: :livelustre,
    adapter: Ecto.Adapters.Postgres
end
