defmodule MountainNerves.Bot.Commands.EstimateTrail do
  @moduledoc """
  Handles the /estimate_trail command and the entire trail estimation conversation flow
  """

  use ExGram.Bot, name: :mountain_nerves

  alias MountainNerves.Trails

  # Command handler - start the conversation
  def handle(msg, context) do
    MountainNerves.Bot.log_command("estimate_trail", msg)

    new_context = %{context | extra: %{step: :input_name, trail: %{}}}
    MountainNerves.Bot.save_state(msg, new_context.extra)
    answer(new_context, "🏔️ Introduce el nombre de la ruta")
  end

  # Trail conversation flow - input name
  def handle_text({:text, text, tg_model}, %{extra: %{step: :input_name, trail: trail}} = context) do
    trail = Map.put(trail, :name, text)
    new_context = %{context | extra: %{step: :input_height, trail: trail}}
    MountainNerves.Bot.save_state(tg_model, new_context.extra)
    answer(new_context, "📏 Introduce el desnivel de la ruta en metros")
  end

  # Trail conversation flow - input height
  def handle_text({:text, text, tg_model}, %{extra: %{step: :input_height, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, height} ->
        trail = Map.put(trail, :height, height)
        new_context = %{context | extra: %{step: :input_distance, trail: trail}}
        MountainNerves.Bot.save_state(tg_model, new_context.extra)
        answer(new_context, "📍 Introduce la distancia de la ruta en kilómetros")

      :error ->
        answer(context, "❌ No me has dado un número válido. Introduce el desnivel en metros:")
    end
  end

  # Trail conversation flow - input distance
  def handle_text({:text, text, tg_model}, %{extra: %{step: :input_distance, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, distance} ->
        trail = Map.put(trail, :distance, distance)
        new_context = %{context | extra: %{step: :input_velocity, trail: trail}}
        MountainNerves.Bot.save_state(tg_model, new_context.extra)
        answer(new_context, "🚀 Introduce la velocidad de la ruta en km/h")

      :error ->
        answer(
          context,
          "❌ No me has dado un número válido. Introduce la distancia en kilómetros:"
        )
    end
  end

  # Trail conversation flow - input velocity
  def handle_text({:text, text, tg_model}, %{extra: %{step: :input_velocity, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, velocity} ->
        trail = Map.put(trail, :velocity, velocity)
        new_context = %{context | extra: %{step: :input_weather, trail: trail}}
        MountainNerves.Bot.save_state(tg_model, new_context.extra)
        answer(new_context, "🌦️ ¿Ha habido meteorología extrema? S/N")

      :error ->
        answer(context, "❌ No me has dado un número válido. Introduce la velocidad en km/h:")
    end
  end

  # Trail conversation flow - input weather (final step)
  def handle_text({:text, text, tg_model}, %{extra: %{step: :input_weather, trail: trail}} = context) do
    extreme_temp = String.upcase(text) in ["S", "SI", "Y", "YES"]

    score =
      Trails.compute_score(
        trail.height,
        trail.distance,
        trail.velocity,
        extreme_temp
      )

    # Save to database
    trail_attrs = %{
      name: trail.name,
      height: trail.height,
      distance: trail.distance,
      velocity: trail.velocity,
      extreme_temp: extreme_temp,
      score: score
    }

    case Trails.create_trail(trail_attrs) do
      {:ok, _saved_trail} ->
        classification = Trails.score_classification(score)

        # Clear conversation state - conversation is complete
        MountainNerves.Bot.clear_state(tg_model)

        answer(
          context,
          """
          ✅ Ruta guardada!

          🎯 La puntuación de la ruta es de #{Float.round(score, 2)} sobre 100

          🏆 La ruta se clasifica como: <b>#{classification}</b>
          """,
          parse_mode: "HTML"
        )

      {:error, _changeset} ->
        # Clear conversation state
        MountainNerves.Bot.clear_state(tg_model)

        answer(context, "❌ Error al guardar la ruta. Por favor, inténtalo de nuevo.")
    end
  end

  ## Private helpers

  # Parse float from string, handling both comma and dot as decimal separator
  defp parse_float(text) do
    cleaned = String.replace(text, ",", ".")

    case Float.parse(cleaned) do
      {num, _remainder} -> {:ok, num}
      :error -> :error
    end
  end
end
