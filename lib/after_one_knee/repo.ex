defmodule AfterOneKnee.Repo do
  use Ecto.Repo,
    otp_app: :after_one_knee,
    adapter: Ecto.Adapters.SQLite3
end
