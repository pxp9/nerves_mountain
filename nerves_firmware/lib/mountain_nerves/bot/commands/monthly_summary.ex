defmodule MountainNerves.Bot.Commands.MonthlySummary do
  @moduledoc """
  Handles the /monthly_summary command - Get monthly summary stats
  """

  use ExGram.Bot, name: :mountain_nerves

  alias MountainNerves.Trails

  def handle(msg, context) do
    MountainNerves.Bot.log_command("monthly_summary", msg)

    user_id = MountainNerves.Bot.get_or_create_user(msg.from)

    case Trails.monthly_summary(user_id) do
      {overall_stats, summary} ->
        MountainNerves.Bot.send_paginated_summary(
          context,
          "monthly",
          "Monthly",
          overall_stats,
          summary,
          0
        )

      _error ->
        answer(context, "Error retrieving monthly summary")
    end
  end
end
