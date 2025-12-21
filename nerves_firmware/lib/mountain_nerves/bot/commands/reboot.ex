defmodule MountainNerves.Bot.Commands.Reboot do
  @moduledoc """
  Handles the /reboot command - Reboot the device (admin only)
  """

  use ExGram.Bot, name: :mountain_nerves

  def handle(msg, context) do
    MountainNerves.Bot.log_command("reboot", msg)

    if MountainNerves.Bot.is_admin?(msg) do
      answer(context, "🔄 Rebooting device in 3 seconds...")

      # Schedule reboot (only works on actual Nerves devices)
      if Nerves.Runtime.mix_target() != :host do
        Task.start(fn ->
          Process.sleep(3000)
          :os.cmd(~c"reboot")
        end)
      else
        answer(context, "⚠️ Reboot command not available on host target")
      end
    else
      answer(context, "⛔ Access denied. This command is for the bot owner only.")
    end
  end
end
