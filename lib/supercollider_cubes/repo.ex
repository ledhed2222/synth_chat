defmodule SupercolliderCubes.Repo do
  use Ecto.Repo,
    otp_app: :supercollider_cubes,
    adapter: Ecto.Adapters.Postgres
end
