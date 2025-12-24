defmodule MountainNerves.Bot.Commands.InterannualGraph do
  @moduledoc """
  Handles the /interannual_graph command - Generate and send a graph of interannual trail scores
  """

  use ExGram.Bot, name: :mountain_nerves

  require Logger

  alias MountainNerves.GraphGenerator

  def handle(msg, context) do
    MountainNerves.Bot.log_command("interannual_graph", msg)

    user_id = MountainNerves.Bot.get_or_create_user(msg.from)

    # Send "generating..." message
    ExGram.send_message(msg.chat.id, "📊 Generating interannual graph, please wait...")

    case GraphGenerator.generate_interannual_graph(user_id) do
      {:ok, file_path} ->
        # Send the PNG file as a photo
        chat_id = msg.chat.id

        case ExGram.send_photo(chat_id, {:file, file_path},
               caption: "📊 Interannual Trail Scores Graph 🏔️"
             ) do
          {:ok, _} ->
            # Clean up the temporary file
            File.rm(file_path)
            Logger.info("Graph sent successfully and temp file deleted")

          {:error, reason} ->
            Logger.error("Failed to send graph: #{inspect(reason)}")
            answer(context, "❌ Error sending graph. Please try again.")
            File.rm(file_path)
        end

      {:error, :no_data} ->
        answer(context, "📭 No trail data available for the last 365 days.")

      {:error, reason} ->
        Logger.error("Failed to generate graph: #{inspect(reason)}")
        answer(context, "❌ Error generating graph. Please try again later.")
    end
  end
end
