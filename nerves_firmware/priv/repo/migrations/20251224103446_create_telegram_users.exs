defmodule MountainNerves.Repo.Migrations.CreateTelegramUsers do
  use Ecto.Migration

  def up do
    default_user_id = 905316511

    # Create telegram_users table with telegram_id as primary key
    create table(:telegram_users, primary_key: false) do
      add :telegram_id, :bigint, primary_key: true, null: false
      add :username, :string
      add :first_name, :string
      add :last_name, :string

      timestamps(type: :utc_datetime)
    end

    # Insert the default users
    execute """
    INSERT INTO telegram_users (telegram_id, username, first_name, last_name, inserted_at, updated_at)
    VALUES
      (905316511, 'juanes4498', 'Juan de Juanes', 'Márquez', datetime('now'), datetime('now')),
      (1350890521, 'itz_pxp9', 'Pepe', 'Márquez', datetime('now'), datetime('now'))
    """

    # SQLite doesn't support ALTER COLUMN, so we need to recreate the table
    # This is the recommended SQLite approach for adding NOT NULL columns

    # Disable foreign key constraints temporarily
    execute "PRAGMA foreign_keys = OFF"

    # Create new trails table with user_id column
    execute """
    CREATE TABLE trails_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      height REAL NOT NULL,
      distance REAL NOT NULL,
      velocity REAL NOT NULL,
      weather_condition TEXT DEFAULT 'normal',
      score REAL NOT NULL,
      user_id INTEGER NOT NULL,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES telegram_users(telegram_id) ON DELETE CASCADE
    )
    """

    # Copy data from old table to new table, setting user_id to default_user_id
    execute """
    INSERT INTO trails_new (id, name, height, distance, velocity, weather_condition, score, user_id, inserted_at, updated_at)
    SELECT id, name, height, distance, velocity, weather_condition, score, #{default_user_id}, inserted_at, updated_at
    FROM trails
    """

    # Drop old table
    execute "DROP TABLE trails"

    # Rename new table to original name
    execute "ALTER TABLE trails_new RENAME TO trails"

    # Re-enable foreign key constraints
    execute "PRAGMA foreign_keys = ON"

    # Create index on user_id for faster queries
    create index(:trails, [:user_id])

    # Create unique constraint on user_id and date(inserted_at)
    create unique_index(:trails, [:user_id, :inserted_at],
             name: :trails_user_id_date_unique_index
           )
  end

  def down do
    # Drop the unique index
    drop unique_index(:trails, [:user_id, :inserted_at],
           name: :trails_user_id_date_unique_index
         )

    # Drop the index on user_id
    drop index(:trails, [:user_id])

    # Recreate trails table without user_id column
    execute "PRAGMA foreign_keys = OFF"

    execute """
    CREATE TABLE trails_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      height REAL NOT NULL,
      distance REAL NOT NULL,
      velocity REAL NOT NULL,
      weather_condition TEXT DEFAULT 'normal',
      score REAL NOT NULL,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """

    execute """
    INSERT INTO trails_new (id, name, height, distance, velocity, weather_condition, score, inserted_at, updated_at)
    SELECT id, name, height, distance, velocity, weather_condition, score, inserted_at, updated_at
    FROM trails
    """

    execute "DROP TABLE trails"
    execute "ALTER TABLE trails_new RENAME TO trails"
    execute "PRAGMA foreign_keys = ON"

    # Recreate original indexes
    create index(:trails, [:name])
    create index(:trails, [:inserted_at])

    # Drop telegram_users table
    drop table(:telegram_users)
  end
end
