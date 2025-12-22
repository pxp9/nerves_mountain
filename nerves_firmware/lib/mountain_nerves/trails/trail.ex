defmodule MountainNerves.Trails.Trail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trails" do
    field(:name, :string)
    field(:height, :float)
    field(:distance, :float)
    field(:velocity, :float)
    field(:weather_condition, Ecto.Enum, values: [:normal, :extreme, :snow], default: :normal)
    field(:score, :float)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trail, attrs) do
    trail
    |> cast(attrs, [:name, :height, :distance, :velocity, :weather_condition, :score, :inserted_at, :updated_at])
    |> validate_required([:name, :height, :distance, :velocity, :score])
    |> validate_number(:height, greater_than_or_equal_to: 0)
    |> validate_number(:distance, greater_than_or_equal_to: 0)
    |> validate_number(:velocity, greater_than_or_equal_to: 0)
    |> validate_number(:score, greater_than_or_equal_to: 0)
  end
end
