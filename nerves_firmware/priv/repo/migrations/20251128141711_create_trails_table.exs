defmodule MountainNerves.Repo.Migrations.CreateTrailsTable do
  use Ecto.Migration

  def change do
    create table(:trails) do
      add :name, :string, null: false
      add :height, :float, null: false
      add :distance, :float, null: false
      add :velocity, :float, null: false
      add :extreme_temp, :boolean, default: false, null: false
      add :score, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:trails, [:name])
    create index(:trails, [:inserted_at])
  end
end
