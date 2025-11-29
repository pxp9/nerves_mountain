defmodule MountainNerves.Middleware.ConversationState do
  @moduledoc """
  Middleware that persists conversation state (context.extra) between messages.

  This allows the bot to maintain multi-step conversations by storing and retrieving
  the extra map based on the user's chat ID.

  Uses an Agent to store state in memory.
  """

  use ExGram.Middleware

  require Logger

  @state_agent __MODULE__.StateAgent

  def init(opts) do
    # Start the state agent if it's not already running
    # This is called on every message, but Agent will only start once
    case Agent.start_link(fn -> %{} end, name: @state_agent) do
      {:ok, _pid} ->
        Logger.info("ConversationState: Started state agent")
        opts

      {:error, {:already_started, _pid}} ->
        Logger.debug("ConversationState: State agent already running")
        opts

      {:error, reason} ->
        Logger.error("ConversationState: Failed to start state agent: #{inspect(reason)}")
        opts
    end
  end

  def call(%ExGram.Cnt{update: update} = cnt, _opts) do
    chat_id = get_chat_id(update)

    # Load state for this chat
    loaded_extra = load_state(chat_id)

    # Merge loaded state with current extra (current extra takes precedence)
    merged_extra = Map.merge(loaded_extra, cnt.extra)
    cnt = %{cnt | extra: merged_extra}

    # Store the state after processing (this happens via the answer/2 function in bot.ex)
    # We need to intercept the response to save state
    # Since middleware runs before handle, we'll save on every message
    cnt
  end

  @doc """
  Saves the conversation state for a given chat ID.
  This should be called after updating context.extra in handlers.
  """
  def save_state(chat_id, extra) when is_map(extra) do
    Agent.update(@state_agent, fn state ->
      Map.put(state, chat_id, extra)
    end)
  end

  @doc """
  Loads the conversation state for a given chat ID.
  Returns an empty map if no state exists.
  """
  def load_state(chat_id) do
    Agent.get(@state_agent, fn state ->
      Map.get(state, chat_id, %{})
    end)
  end

  @doc """
  Clears the conversation state for a given chat ID.
  """
  def clear_state(chat_id) do
    Agent.update(@state_agent, fn state ->
      Map.delete(state, chat_id)
    end)
  end

  # Extract chat_id from update
  defp get_chat_id(%ExGram.Model.Update{message: %{chat: %{id: id}}}), do: id
  defp get_chat_id(%ExGram.Model.Update{edited_message: %{chat: %{id: id}}}), do: id
  defp get_chat_id(%ExGram.Model.Update{channel_post: %{chat: %{id: id}}}), do: id
  defp get_chat_id(%ExGram.Model.Update{edited_channel_post: %{chat: %{id: id}}}), do: id
  defp get_chat_id(%ExGram.Model.Update{callback_query: %{message: %{chat: %{id: id}}}}), do: id
  defp get_chat_id(_), do: nil
end
