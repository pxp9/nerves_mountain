defmodule MountainNerves.TrailsTest do
  use ExUnit.Case, async: true
  alias MountainNerves.{Repo, Trails}
  alias MountainNerves.Trails.Trail

  setup do
    # Explicitly get a connection
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "compute_score/4" do
    test "calculates score with normal weather" do
      score = Trails.compute_score(1000, 15, 2.5, :normal)
      # Expected: (1000/1500 * 0.5 + 15/23 * 0.3 + 2.5/3.2 * 0.2) * 100
      # = (0.6667 * 0.5 + 0.6522 * 0.3 + 0.7813 * 0.2) * 100
      # = (0.3333 + 0.1957 + 0.1563) * 100 = 68.53
      assert_in_delta score, 68.53, 0.5
    end

    test "calculates score with extreme weather multiplier" do
      score_normal = Trails.compute_score(1000, 15, 2.5, :normal)
      score_extreme = Trails.compute_score(1000, 15, 2.5, :extreme)

      assert_in_delta score_extreme, score_normal * 1.15, 0.1
    end

    test "calculates score with snow weather multiplier" do
      score_normal = Trails.compute_score(1000, 15, 2.5, :normal)
      score_snow = Trails.compute_score(1000, 15, 2.5, :snow)

      assert_in_delta score_snow, score_normal * 1.10, 0.1
    end

    test "handles edge case with zero values" do
      score = Trails.compute_score(0, 0, 0)
      assert score == 0.0
    end

    test "handles maximum values" do
      score = Trails.compute_score(1500, 23, 3.2)
      assert_in_delta score, 100.0, 0.1
    end

    test "handles values above maximum" do
      score = Trails.compute_score(2000, 30, 4.0)
      assert score > 100.0
    end
  end

  describe "score_classification/1" do
    test "classifies TURISTA DE MIERDA" do
      assert Trails.score_classification(0) == "TURISTA DE MIERDA"
      assert Trails.score_classification(30) == "TURISTA DE MIERDA"
      assert Trails.score_classification(34.9) == "TURISTA DE MIERDA"
    end

    test "classifies CHICHINABO INFERIOR" do
      assert Trails.score_classification(35) == "CHICHINABO INFERIOR"
      assert Trails.score_classification(40) == "CHICHINABO INFERIOR"
      assert Trails.score_classification(44.9) == "CHICHINABO INFERIOR"
    end

    test "classifies CHICHINABO SUPERIOR" do
      assert Trails.score_classification(45) == "CHICHINABO SUPERIOR"
      assert Trails.score_classification(48) == "CHICHINABO SUPERIOR"
      assert Trails.score_classification(49.9) == "CHICHINABO SUPERIOR"
    end

    test "classifies APAÑÁ" do
      assert Trails.score_classification(50) == "APAÑÁ"
      assert Trails.score_classification(55) == "APAÑÁ"
      assert Trails.score_classification(59.9) == "APAÑÁ"
    end

    test "classifies RUTÓN" do
      assert Trails.score_classification(60) == "RUTÓN"
      assert Trails.score_classification(75) == "RUTÓN"
      assert Trails.score_classification(79.9) == "RUTÓN"
    end

    test "classifies PUTO INFIERNO" do
      assert Trails.score_classification(80) == "PUTO INFIERNO"
      assert Trails.score_classification(95) == "PUTO INFIERNO"
      assert Trails.score_classification(150) == "PUTO INFIERNO"
    end
  end

  describe "create_trail/1" do
    test "creates a valid trail with normal weather" do
      attrs = %{
        name: "Test Trail",
        height: 1000.0,
        distance: 15.0,
        velocity: 2.5,
        weather_condition: :normal,
        score: 68.5
      }

      assert {:ok, %Trail{} = trail} = Trails.create_trail(attrs)
      assert trail.name == "Test Trail"
      assert trail.height == 1000.0
      assert trail.distance == 15.0
      assert trail.velocity == 2.5
      assert trail.weather_condition == :normal
      assert trail.score == 68.5
      assert trail.id != nil
    end

    test "requires name field" do
      attrs = %{
        height: 1000.0,
        distance: 15.0,
        velocity: 2.5,
        score: 68.5
      }

      assert {:error, changeset} = Trails.create_trail(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates height is non-negative" do
      attrs = %{
        name: "Test",
        height: -100.0,
        distance: 15.0,
        velocity: 2.5,
        score: 68.5
      }

      assert {:error, changeset} = Trails.create_trail(attrs)
      assert %{height: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "creates trail with extreme weather" do
      attrs = %{
        name: "Extreme Trail",
        height: 1200.0,
        distance: 18.0,
        velocity: 2.8,
        weather_condition: :extreme,
        score: 85.0
      }

      assert {:ok, %Trail{} = trail} = Trails.create_trail(attrs)
      assert trail.weather_condition == :extreme
    end

    test "creates trail with snow weather" do
      attrs = %{
        name: "Snow Trail",
        height: 1100.0,
        distance: 16.0,
        velocity: 2.6,
        weather_condition: :snow,
        score: 75.0
      }

      assert {:ok, %Trail{} = trail} = Trails.create_trail(attrs)
      assert trail.weather_condition == :snow
    end
  end

  describe "list_trails/0" do
    test "returns empty list when no trails" do
      assert Trails.list_trails() == []
    end

    test "returns all trails" do
      create_test_trail("Trail 1", 1000, 15, 2.5)
      create_test_trail("Trail 2", 800, 12, 2.2)

      trails = Trails.list_trails()
      assert length(trails) == 2
    end
  end

  describe "get_trail!/1" do
    test "retrieves a trail by id" do
      {:ok, created} = create_test_trail("Test Trail", 1000, 15, 2.5)
      retrieved = Trails.get_trail!(created.id)

      assert retrieved.id == created.id
      assert retrieved.name == "Test Trail"
    end

    test "raises when trail not found" do
      assert_raise Ecto.NoResultsError, fn ->
        Trails.get_trail!(999_999)
      end
    end
  end

  describe "monthly_summary/0" do
    test "returns empty summary when no trails" do
      {summary, {cum_distance, cum_height, cum_score}} = Trails.monthly_summary()

      assert summary == []
      assert cum_distance == 0.0
      assert cum_height == 0.0
      assert cum_score == 0.0
    end

    test "aggregates trails by name" do
      # Create multiple trails with same name
      create_test_trail("Maliciosa", 1000, 15, 2.5)
      create_test_trail("Maliciosa", 1100, 16, 2.6)
      create_test_trail("Peñalara", 800, 12, 2.2)

      {summary, {cum_distance, cum_height, cum_score}} = Trails.monthly_summary()

      assert length(summary) == 2
      assert cum_distance > 0
      assert cum_height > 0
      assert cum_score > 0

      # Find Maliciosa stats
      {_name, freq, _velocity, _distance, _height, _score} =
        Enum.find(summary, fn {name, _, _, _, _, _} -> name == "Maliciosa" end)

      assert freq == 2
    end

    test "calculates cumulative sums correctly" do
      create_test_trail("Trail 1", 1000, 15, 2.5)
      create_test_trail("Trail 2", 500, 10, 2.0)

      {_summary, {cum_distance, cum_height, cum_score}} = Trails.monthly_summary()

      assert_in_delta cum_distance, 25.0, 0.1
      assert_in_delta cum_height, 1500.0, 0.1
      assert cum_score > 0
    end
  end

  describe "annual_summary/0" do
    test "returns summary for last 365 days" do
      create_test_trail("Test Trail", 1000, 15, 2.5)

      {summary, {cum_distance, cum_height, cum_score}} = Trails.annual_summary()

      assert length(summary) >= 1
      assert cum_distance > 0
      assert cum_height > 0
      assert cum_score > 0
    end
  end

  # Helper functions
  defp create_test_trail(name, height, distance, velocity, weather_condition \\ :normal) do
    score = Trails.compute_score(height, distance, velocity, weather_condition)

    Trails.create_trail(%{
      name: name,
      height: height * 1.0,
      distance: distance * 1.0,
      velocity: velocity,
      weather_condition: weather_condition,
      score: score
    })
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
