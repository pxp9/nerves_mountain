defmodule MountainNerves.Bot.Commands.InterannualSummary do
  @moduledoc """
  Handles the /interannual_summary command - Get interannual summary (last 365 days)
  """

  use ExGram.Bot, name: :mountain_nerves

  alias MountainNerves.Trails

  def handle(msg, context) do
    MountainNerves.Bot.log_command("interannual_summary", msg)

    case Trails.interannual_summary() do
      {overall_stats, summary} ->
        MountainNerves.Bot.send_paginated_summary(
          context,
          "interannual",
          "Interannual (Last 365 Days)",
          overall_stats,
          summary,
          0
        )

      _error ->
        answer(context, "Error retrieving interannual summary")
    end
  end
end
