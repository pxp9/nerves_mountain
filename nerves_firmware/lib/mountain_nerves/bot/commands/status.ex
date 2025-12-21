defmodule MountainNerves.Bot.Commands.Status do
  @moduledoc """
  Handles the /status command - Show system status (admin only)
  """

  use ExGram.Bot, name: :mountain_nerves

  def handle(msg, context) do
    MountainNerves.Bot.log_command("status", msg)

    if MountainNerves.Bot.is_admin?(msg) do
      status_info = MountainNerves.Bot.get_system_status()
      answer(context, status_info, parse_mode: "HTML")
    else
      answer(context, "⛔ Access denied. This command is for the bot owner only.")
    end
  end
end
