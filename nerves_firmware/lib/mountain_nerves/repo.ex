defmodule MountainNerves.Repo do
  use Ecto.Repo,
    otp_app: :mountain_nerves,
    adapter: Ecto.Adapters.SQLite3
end
