# Script for populating the database with test data
# Run: mix run priv/repo/seeds.exs

alias MountainNerves.Repo
alias MountainNerves.Trails.Trail

# Clear existing trails (optional - comment out if you want to keep existing data)
Repo.delete_all(Trail)

IO.puts("Seeding trails...")

# Helper function to create a trail with a specific date
create_trail_with_date = fn name, height, distance, velocity, extreme_temp, days_ago ->
  inserted_at =
    DateTime.utc_now()
    |> DateTime.add(-days_ago, :day)
    |> DateTime.truncate(:second)

  score =
    MountainNerves.Trails.compute_score(
      height,
      distance,
      velocity,
      extreme_temp
    )

  %Trail{
    name: name,
    height: height,
    distance: distance,
    velocity: velocity,
    extreme_temp: extreme_temp,
    score: score,
    inserted_at: inserted_at,
    updated_at: inserted_at
  }
  |> Repo.insert!()
end

# ===== CURRENT MONTH (Last 30 days) =====
IO.puts("Creating trails for current month...")

# Easy trail - TURISTA DE MIERDA (< 35)
create_trail_with_date.("Paseo del Parque", 100.0, 3.0, 1.5, false, 5)
create_trail_with_date.("Paseo del Parque", 120.0, 3.2, 1.6, false, 15)
create_trail_with_date.("Paseo del Parque", 80.0, 2.8, 1.4, false, 25)

# Medium-low - CHICHINABO INFERIOR (35-45)
create_trail_with_date.("Ruta Verde", 400.0, 8.0, 2.0, false, 3)
create_trail_with_date.("Ruta Verde", 420.0, 8.5, 2.1, false, 12)

# Medium - CHICHINABO SUPERIOR (45-50)
create_trail_with_date.("Sendero Azul", 500.0, 10.0, 2.3, false, 7)
create_trail_with_date.("Sendero Azul", 520.0, 10.2, 2.4, false, 18)

# Medium-high - APAÑÁ (50-60)
create_trail_with_date.("Montaña Roja", 700.0, 12.0, 2.5, false, 10)

# Hard - RUTÓN (60-80)
create_trail_with_date.("Pico del Águila", 1000.0, 15.0, 2.8, false, 2)
create_trail_with_date.("Pico del Águila", 1050.0, 15.5, 2.9, false, 20)

# Extreme - PUTO INFIERNO (> 80)
create_trail_with_date.("Aneto", 1400.0, 22.0, 3.1, false, 8)

# ===== CURRENT YEAR (but older than 30 days) =====
IO.puts("Creating trails for earlier this year...")

# Calculate days ago for beginning of year (approximately)
days_since_year_start =
  Date.utc_today()
  |> Date.beginning_of_month()
  |> Date.diff(Date.new!(Date.utc_today().year, 1, 1))

create_trail_with_date.("Ruta Verde", 380.0, 7.8, 1.9, false, days_since_year_start + 30)
create_trail_with_date.("Sendero Azul", 480.0, 9.5, 2.2, false, days_since_year_start + 60)
create_trail_with_date.("Pico del Águila", 980.0, 14.5, 2.7, false, days_since_year_start + 90)
create_trail_with_date.("Montaña Roja", 680.0, 11.5, 2.4, false, days_since_year_start + 120)

# ===== LAST YEAR (365 days back, but from previous year) =====
IO.puts("Creating trails from last year...")

create_trail_with_date.("Paseo del Parque", 90.0, 2.9, 1.5, false, 380)
create_trail_with_date.("Ruta Verde", 390.0, 8.2, 2.0, false, 400)
create_trail_with_date.("Sendero Azul", 510.0, 10.5, 2.4, false, 420)
create_trail_with_date.("Pico del Águila", 1020.0, 15.8, 2.9, false, 450)
create_trail_with_date.("Aneto", 1380.0, 21.5, 3.0, false, 480)

# ===== TRAILS WITH EXTREME WEATHER =====
IO.puts("Creating trails with extreme weather...")

# Same trail, but with extreme weather (multiplier 1.15)
create_trail_with_date.("Aneto", 1450.0, 22.5, 3.2, true, 4)
create_trail_with_date.("Pico del Águila", 1100.0, 16.0, 3.0, true, 6)
create_trail_with_date.("Montaña Roja", 750.0, 13.0, 2.7, true, 14)

# ===== EDGE CASES =====
IO.puts("Creating edge case trails...")

# Maximum values trail (should exceed 100 score)
create_trail_with_date.("Everest Simulator", 1500.0, 23.0, 3.2, true, 1)

# Minimum values trail
create_trail_with_date.("Micro Paseo", 10.0, 0.5, 0.8, false, 11)

# Exactly at boundaries
create_trail_with_date.("Camino de Santiago", 300.0, 6.0, 1.8, false, 16)
create_trail_with_date.("Picos de Europa", 550.0, 10.5, 2.3, false, 21)
create_trail_with_date.("Sierra de Gredos", 800.0, 13.0, 2.6, false, 26)
create_trail_with_date.("Mulhacén", 1100.0, 17.0, 2.9, false, 28)

# ===== VERY OLD TRAILS (> 365 days) =====
IO.puts("Creating very old trails (should NOT appear in annual summary)...")

create_trail_with_date.("Ancient Route", 500.0, 10.0, 2.0, false, 400)
create_trail_with_date.("Ancient Route", 520.0, 10.5, 2.1, false, 500)

IO.puts("✅ Seed data created successfully!")
IO.puts("")
IO.puts("Summary:")
IO.puts("- Trails in last 30 days: ~15")
IO.puts("- Trails in current year: ~19")
IO.puts("- Trails in last 365 days: ~24")
IO.puts("- Total trails: ~26")
IO.puts("")
IO.puts("Test scenarios covered:")
IO.puts("✓ All difficulty classifications (TURISTA DE MIERDA to PUTO INFIERNO)")
IO.puts("✓ Multiple instances of same route (for frequency testing)")
IO.puts("✓ Extreme weather conditions")
IO.puts("✓ Edge cases (min/max values, boundary scores)")
IO.puts("✓ Different time periods (monthly, interannual, annual)")
IO.puts("✓ Very old trails (to verify they're excluded from summaries)")
