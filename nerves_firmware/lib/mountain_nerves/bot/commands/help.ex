defmodule MountainNerves.Bot.Commands.Help do
  @moduledoc """
  Handles the /help command - Display help text with all available commands
  """

  use ExGram.Bot, name: :mountain_nerves

  def handle(msg, context) do
    MountainNerves.Bot.log_command("help", msg)

    answer(
      context,
      """
      <b>Trail Evaluator Bot</b>

      📊 <b>Trail Commands</b>
      /estimate_trail - Estimate the difficulty of a trail
      /annual_summary - Get annual summary stats (current year)
      /interannual_graph - Generate a graph of interannual trail scores (last 365 days)
      /interannual_summary - Get interannual summary stats (last 365 days)
      /monthly_summary - Get monthly summary stats

      ⚙️ <b>Admin Commands</b>
      /admin - View admin commands
      /status - Show system status (admin only)
      /reboot - Reboot the device (admin only)

      /help - Show this message
      """,
      parse_mode: "HTML"
    )
  end
end
