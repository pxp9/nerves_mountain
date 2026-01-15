defmodule MountainNerves.Trails.Trail do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "trails" do
    field(:name, :string)
    field(:height, :float)
    field(:distance, :float)
    field(:velocity, :float)
    field(:weather_condition, Ecto.Enum, values: [:normal, :extreme, :snow], default: :normal)
    field(:score, :float)

    belongs_to(:user, MountainNerves.TelegramUsers.TelegramUser, foreign_key: :user_id, references: :telegram_id, type: :integer)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trail, attrs) do
    trail
    |> cast(attrs, [:name, :height, :distance, :velocity, :weather_condition, :score, :user_id, :inserted_at, :updated_at])
    |> validate_required([:name, :height, :distance, :velocity, :score])
    |> validate_number(:height, greater_than_or_equal_to: 0)
    |> validate_number(:distance, greater_than_or_equal_to: 0)
    |> validate_number(:velocity, greater_than_or_equal_to: 0)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> validate_one_trail_per_day()
    |> unique_constraint([:user_id, :inserted_at],
      name: :trails_user_id_date_unique_index,
      message: "user can only have one trail per day"
    )
  end

  defp validate_one_trail_per_day(changeset) do
    user_id = get_field(changeset, :user_id)
    inserted_at = get_field(changeset, :inserted_at) || DateTime.utc_now()

    if user_id do
      # Get the date from the inserted_at timestamp
      date = DateTime.to_date(inserted_at)

      # Create datetime range for the entire day in UTC
      day_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      day_end = DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")

      # Check if a trail already exists for this user on this date
      query =
        from t in MountainNerves.Trails.Trail,
          where: t.user_id == ^user_id,
          where: t.inserted_at >= ^day_start and t.inserted_at <= ^day_end

      # Exclude the current trail if it's an update
      query =
        if trail_id = get_field(changeset, :id) do
          from t in query, where: t.id != ^trail_id
        else
          query
        end

      case MountainNerves.Repo.exists?(query) do
        true ->
          add_error(changeset, :inserted_at, "user can only have one trail per day")

        false ->
          changeset
      end
    else
      changeset
    end
  end
end
