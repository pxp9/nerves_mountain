defmodule MountainNerves.Bot.Commands.Start do
  @moduledoc """
  Handles the /start command - Welcome message for new users
  """

  use ExGram.Bot, name: :mountain_nerves

  def handle(msg, context) do
    MountainNerves.Bot.log_command("start", msg)

    answer(
      context,
      """
      👋 Welcome to the Trail Evaluator Bot!

      I help you track and evaluate mountain trail difficulty scores.

      Use /help to see all available commands.
      """,
      parse_mode: "HTML"
    )
  end
end
