ExUnit.start()

# Start the application to ensure Repo is running
{:ok, _} = Application.ensure_all_started(:mountain_nerves)

# Run migrations for test database (before enabling sandbox mode)
Ecto.Migrator.run(MountainNerves.Repo, "priv/repo/migrations", :up, all: true)

# Set up Ecto sandbox for testing
Ecto.Adapters.SQL.Sandbox.mode(MountainNerves.Repo, :manual)
