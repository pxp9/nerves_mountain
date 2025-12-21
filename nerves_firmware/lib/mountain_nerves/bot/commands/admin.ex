defmodule MountainNerves.Bot.Commands.Admin do
  @moduledoc """
  Handles the /admin command - Display admin-specific commands
  """

  use ExGram.Bot, name: :mountain_nerves

  def handle(msg, context) do
    MountainNerves.Bot.log_command("admin", msg)

    if MountainNerves.Bot.is_admin?(msg) do
      answer(
        context,
        """
        <b>Admin Commands</b>

        /status - Show system status
        /reboot - Reboot the device

        You are authorized as the bot owner.
        """,
        parse_mode: "HTML"
      )
    else
      answer(context, "⛔ Access denied. This command is for the bot owner only.")
    end
  end
end
