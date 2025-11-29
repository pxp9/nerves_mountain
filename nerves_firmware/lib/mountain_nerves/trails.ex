defmodule MountainNerves.Trails do
  @moduledoc """
  The Trails context for managing trail tracking and statistics.
  """

  import Ecto.Query, warn: false
  alias MountainNerves.Repo
  alias MountainNerves.Trails.Trail

  # Score thresholds for classification
  @turista_de_mierda 35
  @chichinabo_inferior 45
  @chichinabo_superior 50
  @overchichi 60
  @ruton 80
  @_puto_infierno 100

  # Calculation constants
  @max_height 1500
  @max_distance 23
  @max_velocity 3.2
  @extreme_weather_multiplier 1.15

  @doc """
  Computes the trail difficulty score based on height, distance, velocity, and weather.

  Score formula:
  - Height contributes 50% (normalized to MAX_HEIGHT = 1500m)
  - Distance contributes 30% (normalized to MAX_DISTANCE = 23km)
  - Velocity contributes 20% (normalized to MAX_VELOCITY = 3.2 km/h)
  - Extreme weather multiplies final score by 1.15

  Returns a score from 0-100+
  """
  def compute_score(height, distance, velocity, extreme_temp \\ false) do
    score =
      height / @max_height * 0.5 +
        distance / @max_distance * 0.3 +
        velocity / @max_velocity * 0.2

    score = score * 100

    if extreme_temp do
      score * @extreme_weather_multiplier
    else
      score
    end
  end

  @doc """
  Returns the classification string for a given score.
  """
  def score_classification(score) do
    cond do
      score < @turista_de_mierda -> "TURISTA DE MIERDA"
      score < @chichinabo_inferior -> "CHICHINABO INFERIOR"
      score < @chichinabo_superior -> "CHICHINABO SUPERIOR"
      score < @overchichi -> "APAÑÁ"
      score < @ruton -> "RUTÓN"
      true -> "PUTO INFIERNO"
    end
  end

  @doc """
  Creates a new trail entry.
  """
  def create_trail(attrs \\ %{}) do
    %Trail{}
    |> Trail.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the list of all trails.
  """
  def list_trails do
    Repo.all(Trail)
  end

  @doc """
  Gets a single trail.
  """
  def get_trail!(id), do: Repo.get!(Trail, id)

  @doc """
  Gets trails from a specific date onwards.
  """
  def get_trails_from_date(from_date) do
    Trail
    |> where([t], t.inserted_at >= ^from_date)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns annual summary statistics (last 365 days).
  Returns {overall_stats, summary_by_name}
  """
  def annual_summary do
    one_year_ago = DateTime.utc_now() |> DateTime.add(-365, :day)
    n_time_summary(one_year_ago)
  end

  @doc """
  Returns interannual summary statistics (from beginning of current year).
  Returns {overall_stats, summary_by_name}
  """
  def interannual_summary do
    beginning_of_year = get_beginning_of_year()
    n_time_summary(beginning_of_year)
  end

  @doc """
  Returns monthly summary statistics (last 30 days).
  Returns {overall_stats, summary_by_name}
  """
  def monthly_summary do
    month_ago = DateTime.utc_now() |> DateTime.add(-30, :day)
    n_time_summary(month_ago)
  end

  defp get_beginning_of_year do
    now = DateTime.utc_now()
    year = now.year

    # Create datetime for January 1st at 00:00:00 of current year
    {:ok, beginning} = DateTime.new(Date.new!(year, 1, 1), Time.new!(0, 0, 0))
    beginning
  end

  @doc """
  Returns summary statistics from a specific datetime.
  Returns {overall_stats, summary_by_name}

  overall_stats is a tuple:
  {total_distance, total_height, total_score, avg_distance, avg_velocity, avg_score, total_count}

  summary_by_name is a list of tuples:
  [{name, count, avg_velocity, avg_distance, avg_height, avg_score}, ...]
  """
  def n_time_summary(from_datetime) do
    summary_by_name = summary_by_name_query(from_datetime)
    overall_stats = overall_stats_query(from_datetime)

    {overall_stats, summary_by_name}
  end

  defp summary_by_name_query(from_datetime) do
    Trail
    |> where([t], t.inserted_at >= ^from_datetime)
    |> group_by([t], t.name)
    |> select([t], {
      t.name,
      count(t.id),
      avg(t.velocity),
      avg(t.distance),
      avg(t.height),
      avg(t.score)
    })
    |> Repo.all()
  end

  defp overall_stats_query(from_datetime) do
    result =
      Trail
      |> where([t], t.inserted_at >= ^from_datetime)
      |> select([t], {
        sum(t.distance),
        sum(t.height),
        sum(t.score),
        avg(t.distance),
        avg(t.velocity),
        avg(t.score),
        count(t.id)
      })
      |> Repo.one()

    case result do
      {nil, nil, nil, nil, nil, nil, nil} -> {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0}
      result -> result
    end
  end

  @doc """
  Finds the trail closest to a given datetime.
  """
  def closest_date_trail(target_datetime) do
    # Convert datetime to unix timestamp for comparison
    target_timestamp = DateTime.to_unix(target_datetime)

    result =
      Trail
      |> select([t], %{
        trail: t,
        time_diff: fragment("ABS(? - unixepoch(?))", ^target_timestamp, t.inserted_at)
      })
      |> order_by([t], fragment("ABS(? - unixepoch(?))", ^target_timestamp, t.inserted_at))
      |> limit(1)
      |> Repo.one()

    case result do
      nil -> nil
      %{trail: trail} -> trail
    end
  end

  @doc """
  Updates a trail's name.
  """
  def update_trail_name(trail, name) do
    trail
    |> Trail.changeset(%{name: name})
    |> Repo.update()
  end
end
