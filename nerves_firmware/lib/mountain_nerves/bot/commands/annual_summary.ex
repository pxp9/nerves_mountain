defmodule MountainNerves.Bot.Commands.AnnualSummary do
  @moduledoc """
  Handles the /annual_summary command - Get annual trail summary (current year)
  """

  use ExGram.Bot, name: :mountain_nerves

  alias MountainNerves.Trails

  def handle(msg, context) do
    MountainNerves.Bot.log_command("annual_summary", msg)

    user_id = MountainNerves.Bot.get_or_create_user(msg.from)

    case Trails.annual_summary(user_id) do
      {overall_stats, summary} ->
        MountainNerves.Bot.send_paginated_summary(
          context,
          "annual",
          "Annual (Current Year)",
          overall_stats,
          summary,
          0
        )

      _error ->
        answer(context, "Error retrieving annual summary")
    end
  end
end
