defmodule MountainNerves.TelegramUsers.TelegramUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:telegram_id, :integer, autogenerate: false}
  schema "telegram_users" do
    field(:username, :string)
    field(:first_name, :string)
    field(:last_name, :string)

    has_many(:trails, MountainNerves.Trails.Trail, foreign_key: :user_id, references: :telegram_id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(telegram_user, attrs) do
    telegram_user
    |> cast(attrs, [:telegram_id, :username, :first_name, :last_name])
    |> validate_required([:telegram_id])
    |> unique_constraint(:telegram_id, name: :telegram_users_pkey)
  end
end
