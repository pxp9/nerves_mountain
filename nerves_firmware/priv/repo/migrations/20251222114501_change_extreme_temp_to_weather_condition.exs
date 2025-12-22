defmodule MountainNerves.Repo.Migrations.ChangeExtremeTempToWeatherCondition do
  use Ecto.Migration

  def up do
    # Add the new column as text (SQLite doesn't support enums)
    alter table(:trails) do
      add :weather_condition, :text, default: "normal"
    end

    # Migrate data from extreme_temp to weather_condition
    execute """
    UPDATE trails
    SET weather_condition = CASE
      WHEN extreme_temp = 1 THEN 'extreme'
      WHEN extreme_temp = 0 THEN 'normal'
    END
    """

    # Remove the old column
    alter table(:trails) do
      remove :extreme_temp
    end
  end

  def down do
    # Add back the boolean column
    alter table(:trails) do
      add :extreme_temp, :boolean, default: false
    end

    # Migrate data from weather_condition back to extreme_temp
    # Map 'snow' to true (extreme weather)
    execute """
    UPDATE trails
    SET extreme_temp = CASE
      WHEN weather_condition = 'extreme' THEN 1
      WHEN weather_condition = 'snow' THEN 1
      WHEN weather_condition = 'normal' THEN 0
    END
    """

    # Remove the new column
    alter table(:trails) do
      remove :weather_condition
    end
  end
end
