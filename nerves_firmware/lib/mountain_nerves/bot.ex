defmodule MountainNerves.Bot do
  @bot :mountain_nerves

  use ExGram.Bot,
    name: @bot

  require Logger

  alias MountainNerves.Trails
  alias MountainNerves.Middleware.ConversationState

  # Pagination configuration
  @items_per_page 8

  command("start")
  command("help", description: "Print the bot's help")
  command("admin", description: "Admin commands (owner only)")
  command("status", description: "Show system status (admin only)")
  command("reboot", description: "Reboot the device (admin only)")
  command("estimate_trail", description: "Estimate the difficulty of a trail")
  command("annual_summary", description: "Get the annual summary stats")
  command("interannual_summary", description: "Get stats from the beginning of the current year")
  command("monthly_summary", description: "Get the monthly summary stats")

  middleware(ExGram.Middleware.IgnoreUsername)
  middleware(MountainNerves.Middleware.ConversationState)

  def bot(), do: @bot

  ## Put here all the initizalization of the bot which will not require Internet
  def init(_opts) do
    :ok
  end

  def handle({:command, :start, msg}, context) do
    log_command("start", msg)
    result = answer(context, "Hi!")
    Logger.info("Bot: Start response result: #{inspect(result)}")
    result
  end

  def handle({:command, :help, msg}, context) do
    log_command("help", msg)

    answer(
      context,
      """
      <b>Trail Evaluator Bot</b>

      📊 <b>Trail Commands</b>
      /estimate_trail - Estimate the difficulty of a trail
      /annual_summary - Get annual summary stats (last 365 days)
      /interannual_summary - Get year-to-date stats
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

  def handle({:command, :admin, msg}, context) do
    log_command("admin", msg)

    if is_admin?(msg) do
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

  def handle({:command, :status, msg}, context) do
    log_command("status", msg)

    if is_admin?(msg) do
      status_info = get_system_status()
      answer(context, status_info, parse_mode: "HTML")
    else
      answer(context, "⛔ Access denied. This command is for the bot owner only.")
    end
  end

  def handle({:command, :reboot, msg}, context) do
    log_command("reboot", msg)

    if is_admin?(msg) do
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

  # Trail estimation conversation flow
  def handle({:command, :estimate_trail, msg}, context) do
    log_command("estimate_trail", msg)

    new_context = %{context | extra: %{step: :input_name, trail: %{}}}
    save_state(msg, new_context.extra)
    answer(new_context, "🏔️ Introduce el nombre de la ruta")
  end

  def handle({:command, :annual_summary, msg}, context) do
    log_command("annual_summary", msg)

    case Trails.annual_summary() do
      {overall_stats, summary} ->
        send_paginated_summary(context, "annual", "Annual", overall_stats, summary, 0)

      _error ->
        answer(context, "Error retrieving annual summary")
    end
  end

  def handle({:command, :interannual_summary, msg}, context) do
    log_command("interannual_summary", msg)

    case Trails.interannual_summary() do
      {overall_stats, summary} ->
        send_paginated_summary(context, "interannual", "Year-to-Date", overall_stats, summary, 0)

      _error ->
        answer(context, "Error retrieving interannual summary")
    end
  end

  def handle({:command, :monthly_summary, msg}, context) do
    log_command("monthly_summary", msg)

    case Trails.monthly_summary() do
      {overall_stats, summary} ->
        send_paginated_summary(context, "monthly", "Monthly", overall_stats, summary, 0)

      _error ->
        answer(context, "Error retrieving monthly summary")
    end
  end

  # Handle pagination callbacks
  def handle({:callback_query, %{data: "summary:" <> data} = query}, _context) do
    [summary_type, page_str] = String.split(data, ":")
    page = String.to_integer(page_str)

    {overall_stats, summary} = case summary_type do
      "annual" -> Trails.annual_summary()
      "interannual" -> Trails.interannual_summary()
      "monthly" -> Trails.monthly_summary()
    end

    period_name = case summary_type do
      "annual" -> "Annual"
      "interannual" -> "Year-to-Date"
      "monthly" -> "Monthly"
    end

    # Edit the message with new page
    edit_paginated_summary(query, summary_type, period_name, overall_stats, summary, page)
  end

  def handle({:info, :init}, _cnt) do
    Logger.info("Init with Internet")

    user = Application.get_env(:mountain_nerves, :tg_owner_user)

    if user do
      send_ip_to_user_with_retry(user)
    end

    :ok
  end

  # Trail conversation flow - input name
  def handle({:text, text, tg_model}, %{extra: %{step: :input_name, trail: trail}} = context) do
    trail = Map.put(trail, :name, text)
    new_context = %{context | extra: %{step: :input_height, trail: trail}}
    save_state(tg_model, new_context.extra)
    answer(new_context, "📏 Introduce el desnivel de la ruta en metros")
  end

  # Trail conversation flow - input height
  def handle({:text, text, tg_model}, %{extra: %{step: :input_height, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, height} ->
        trail = Map.put(trail, :height, height)
        new_context = %{context | extra: %{step: :input_distance, trail: trail}}
        save_state(tg_model, new_context.extra)
        answer(new_context, "📍 Introduce la distancia de la ruta en kilómetros")

      :error ->
        answer(context, "❌ No me has dado un número válido. Introduce el desnivel en metros:")
    end
  end

  # Trail conversation flow - input distance
  def handle({:text, text, tg_model}, %{extra: %{step: :input_distance, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, distance} ->
        trail = Map.put(trail, :distance, distance)
        new_context = %{context | extra: %{step: :input_velocity, trail: trail}}
        save_state(tg_model, new_context.extra)
        answer(new_context, "🚀 Introduce la velocidad de la ruta en km/h")

      :error ->
        answer(
          context,
          "❌ No me has dado un número válido. Introduce la distancia en kilómetros:"
        )
    end
  end

  # Trail conversation flow - input velocity
  def handle({:text, text, tg_model}, %{extra: %{step: :input_velocity, trail: trail}} = context) do
    case parse_float(text) do
      {:ok, velocity} ->
        trail = Map.put(trail, :velocity, velocity)
        new_context = %{context | extra: %{step: :input_weather, trail: trail}}
        save_state(tg_model, new_context.extra)
        answer(new_context, "🌦️ ¿Ha habido meteorología extrema? S/N")

      :error ->
        answer(context, "❌ No me has dado un número válido. Introduce la velocidad en km/h:")
    end
  end

  # Trail conversation flow - input weather (final step)
  def handle({:text, text, tg_model}, %{extra: %{step: :input_weather, trail: trail}} = context) do
    extreme_temp = String.upcase(text) in ["S", "SI", "Y", "YES"]

    score =
      Trails.compute_score(
        trail.height,
        trail.distance,
        trail.velocity,
        extreme_temp
      )

    # Save to database
    trail_attrs = %{
      name: trail.name,
      height: trail.height,
      distance: trail.distance,
      velocity: trail.velocity,
      extreme_temp: extreme_temp,
      score: score
    }

    case Trails.create_trail(trail_attrs) do
      {:ok, _saved_trail} ->
        classification = Trails.score_classification(score)

        # Clear conversation state - conversation is complete
        clear_state(tg_model)

        answer(
          context,
          """
          ✅ Ruta guardada!

          🎯 La puntuación de la ruta es de #{Float.round(score, 2)} sobre 100

          🏆 La ruta se clasifica como: <b>#{classification}</b>
          """,
          parse_mode: "HTML"
        )

      {:error, _changeset} ->
        # Clear conversation state
        clear_state(tg_model)

        answer(context, "❌ Error al guardar la ruta. Por favor, inténtalo de nuevo.")
    end
  end

  # Default text handler - no active conversation
  def handle({:text, text, tg_model}, context) do
    log_command("echo", tg_model)
    answer(context, text)
  end

  def handle({message_type, _tg_model} = _msg, _cnt) do
    Logger.warning("Unhandled update: #{message_type}")
  end

  def handle({message_type, _parsed, _tg_model} = _msg, _cnt) do
    Logger.warning("Unhandled update parsed: #{message_type}")
  end

  # Send paginated summary with navigation buttons
  defp send_paginated_summary(context, summary_type, period_name, overall_stats, summary, page) do
    message = format_summary_page(period_name, overall_stats, summary, page)
    keyboard = build_pagination_keyboard(summary_type, summary, page)

    opts = [parse_mode: "HTML"]
    opts = if keyboard, do: opts ++ [reply_markup: keyboard], else: opts

    answer(context, message, opts)
  end

  # Edit message with new page
  defp edit_paginated_summary(query, summary_type, period_name, overall_stats, summary, page) do
    message = format_summary_page(period_name, overall_stats, summary, page)
    keyboard = build_pagination_keyboard(summary_type, summary, page)

    chat_id = query.message.chat.id
    message_id = query.message.message_id

    opts = [chat_id: chat_id, message_id: message_id, parse_mode: "HTML"]
    opts = if keyboard, do: opts ++ [reply_markup: keyboard], else: opts

    ExGram.edit_message_text(message, opts)
    ExGram.answer_callback_query(query.id)
  end

  # Format a single page of the summary
  defp format_summary_page(period, overall_stats, summary, page) do
    {cum_distance, cum_height, avg_distance, avg_velocity, avg_score, total_count} = overall_stats
    avg_classification = Trails.score_classification(avg_score)

    total_pages = ceil(length(summary) / @items_per_page)
    start_idx = page * @items_per_page
    page_items = Enum.slice(summary, start_idx, @items_per_page)

    overall_text = """
    <b>#{period} Summary (Page #{page + 1}/#{total_pages})</b>

    📊 <b>Overall Statistics (#{total_count} trails):</b>
    📍 Average distance: #{format_number(avg_distance)} km
    🚀 Average velocity: #{format_number(avg_velocity)} km/h
    🎯 Average score: #{format_number(avg_score)} - #{avg_classification} 🏆

    📦 <b>Cumulative Totals:</b>
    📍 Total distance: #{format_number(cum_distance)} km
    🪜 Total height: #{format_height(cum_height)} m

    🗺️ <b>Route Frequencies (sorted by last done):</b>
    """

    frequencies_text =
      page_items
      |> Enum.map(fn {name, freq, _velocity, _distance, _height, score, last_datetime} ->
        last_date = format_datetime(last_datetime)
        score_class = Trails.score_classification(score)
        """
          • <b>#{name}</b>
            Times: #{freq}
            Score: #{format_number(score)} - #{score_class}
            Last done: #{last_date}
        """
      end)
      |> Enum.join("\n")

    overall_text <> frequencies_text
  end

  # Build pagination keyboard with Previous/Next buttons
  defp build_pagination_keyboard(summary_type, summary, page) do
    total_pages = ceil(length(summary) / @items_per_page)

    buttons = []

    # Add Previous button if not on first page
    buttons = if page > 0 do
      [%{text: "⬅️ Previous", callback_data: "summary:#{summary_type}:#{page - 1}"} | buttons]
    else
      buttons
    end

    # Add Next button if not on last page
    buttons = if page < total_pages - 1 do
      buttons ++ [%{text: "Next ➡️", callback_data: "summary:#{summary_type}:#{page + 1}"}]
    else
      buttons
    end

    # Return keyboard markup
    if length(buttons) > 0 do
      %ExGram.Model.InlineKeyboardMarkup{inline_keyboard: [buttons]}
    else
      nil
    end
  end

  # Helper function to check if user is admin
  defp is_admin?(%{from: %{id: user_id}}) do
    owner_user = Application.get_env(:mountain_nerves, :tg_owner_user)

    cond do
      is_nil(owner_user) ->
        Logger.warning("Bot: No owner user configured, denying admin access")
        false

      is_integer(owner_user) ->
        user_id == owner_user

      is_binary(owner_user) ->
        user_id == String.to_integer(owner_user)

      true ->
        Logger.warning("Bot: Invalid owner user type: #{inspect(owner_user)}")
        false
    end
  end

  defp is_admin?(_msg), do: false

  # Get system status information
  defp get_system_status do
    target = Nerves.Runtime.mix_target()
    uptime = get_uptime()
    memory = get_memory_info()

    status = """
    <b>System Status</b>

    <b>Target</b>: #{target}
    <b>Uptime</b>: #{uptime}
    <b>Memory</b>: #{memory}
    """

    if target == :host do
      status <> "\n<i>Running on host (development mode)</i>"
    else
      status
    end
  end

  defp get_uptime do
    case File.read("/proc/uptime") do
      {:ok, content} ->
        [uptime_seconds | _] = String.split(content, " ")
        seconds = String.to_float(uptime_seconds) |> round()
        format_uptime(seconds)

      {:error, _} ->
        "N/A"
    end
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    "#{days}d #{hours}h #{minutes}m"
  end

  defp get_memory_info do
    # Get BEAM VM memory info (always available)
    memory = :erlang.memory()
    total = Keyword.get(memory, :total, 0)
    processes = Keyword.get(memory, :processes, 0)
    system = Keyword.get(memory, :system, 0)

    "Total: #{format_bytes(total)} (Processes: #{format_bytes(processes)}, System: #{format_bytes(system)})"
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  # Helper function to log user commands
  defp log_command(command, msg) do
    user = get_user_info(msg)
    Logger.info("Bot: User #{user} requested /#{command}")
  end

  defp get_user_info(%{from: %{username: username, first_name: first_name, id: id}})
       when not is_nil(username) do
    "@#{username} (#{first_name}, ID: #{id})"
  end

  defp get_user_info(%{from: %{first_name: first_name, id: id}}) do
    "#{first_name} (ID: #{id})"
  end

  defp get_user_info(%{from: %{id: id}}) do
    "User ID: #{id}"
  end

  defp get_user_info(_msg) do
    "Unknown user"
  end

  # Parse float from string, handling both comma and dot as decimal separator
  defp parse_float(text) do
    cleaned = String.replace(text, ",", ".")

    case Float.parse(cleaned) do
      {number, ""} -> {:ok, number}
      {number, _rest} -> {:ok, number}
      :error -> :error
    end
  end

  defp format_number(nil), do: "0.00"
  defp format_number(num) when is_float(num), do: Float.round(num, 2) |> Float.to_string()
  defp format_number(num) when is_integer(num), do: format_integer_with_separators(num)

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(%DateTime{} = dt) do
    "#{dt.year}-#{pad(dt.month)}-#{pad(dt.day)} #{pad(dt.hour)}:#{pad(dt.minute)}"
  end

  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: "#{num}"

  defp format_height(nil), do: "0"
  defp format_height(num) when is_float(num), do: format_integer_with_separators(round(num))
  defp format_height(num) when is_integer(num), do: format_integer_with_separators(num)

  defp format_integer_with_separators(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(" ")
    |> String.reverse()
  end

  # Send IP address with retry logic (spawns async task)
  defp send_ip_to_user_with_retry(user_id) do
    Task.start(fn ->
      send_ip_with_backoff(user_id, 0, 5)
    end)
  end

  # Retry sending IP with exponential backoff
  defp send_ip_with_backoff(user_id, attempt, max_attempts) when attempt < max_attempts do
    case send_ip_to_user(user_id) do
      :ok ->
        :ok

      {:error, %ExGram.Error{code: :nxdomain}} ->
        # DNS resolution failed - network not ready yet
        backoff_ms = (:math.pow(2, attempt) * 1000) |> round()

        Logger.warning(
          "Bot: Network not ready (attempt #{attempt + 1}/#{max_attempts}), retrying in #{backoff_ms}ms"
        )

        Process.sleep(backoff_ms)
        send_ip_with_backoff(user_id, attempt + 1, max_attempts)

      {:error, reason} ->
        # Other errors - retry with backoff
        backoff_ms = (:math.pow(2, attempt) * 1000) |> round()

        Logger.warning(
          "Bot: Failed to send IP (attempt #{attempt + 1}/#{max_attempts}): #{inspect(reason)}, retrying in #{backoff_ms}ms"
        )

        Process.sleep(backoff_ms)
        send_ip_with_backoff(user_id, attempt + 1, max_attempts)
    end
  end

  defp send_ip_with_backoff(user_id, _attempt, max_attempts) do
    Logger.error("Bot: Failed to send IP to user #{user_id} after #{max_attempts} attempts")
    {:error, :max_retries_exceeded}
  end

  # Send IP address to a specific user
  defp send_ip_to_user(user_id) do
    ip_info = get_ip_addresses()
    message = format_ip_message(ip_info)

    case ExGram.send_message(user_id, message, parse_mode: "MarkdownV2") do
      {:ok, _} ->
        Logger.info("Bot: Sent IP address to user #{user_id}")
        :ok

      {:error, reason} ->
        Logger.error("Bot: Failed to send IP to user #{user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Get all network interface IP addresses
  defp get_ip_addresses do
    case :inet.getifaddrs() do
      {:ok, ifaddrs} ->
        ifaddrs
        |> Enum.map(fn {iface, opts} ->
          addrs =
            opts
            |> Enum.filter(fn
              {:addr, _} -> true
              _ -> false
            end)
            |> Enum.map(fn {:addr, addr} -> addr end)
            |> Enum.reject(&is_loopback?/1)

          {to_string(iface), addrs}
        end)
        |> Enum.reject(fn {_iface, addrs} -> Enum.empty?(addrs) end)

      {:error, _} ->
        []
    end
  end

  # Check if address is loopback
  defp is_loopback?({127, 0, 0, 1}), do: true
  defp is_loopback?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp is_loopback?(_), do: false

  # Format IP addresses for message
  defp format_ip_message([]) do
    "*Device Network Information*\n\nNo network interfaces found."
  end

  defp format_ip_message(ip_info) do
    interfaces =
      ip_info
      |> Enum.map_join("\n\n", fn {iface, addrs} ->
        addr_list =
          addrs
          |> Enum.map_join("\n  ", &format_ip_addr/1)

        "*#{iface}*:\n  #{addr_list}"
      end)

    "*Device Network Information*\n\n#{interfaces}"
  end

  # Format IP address tuple to string
  defp format_ip_addr({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}" |> escape_markdown()
  end

  defp format_ip_addr({a, b, c, d, e, f, g, h}) do
    parts = [a, b, c, d, e, f, g, h]

    parts
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
  end

  defp format_ip_addr(addr) do
    inspect(addr)
  end

  # Escape special characters for MarkdownV2
  defp escape_markdown(text) do
    text
    |> String.replace("_", "\\_")
    |> String.replace("*", "\\*")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("~", "\\~")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
    |> String.replace("#", "\\#")
    |> String.replace("+", "\\+")
    |> String.replace("-", "\\-")
    |> String.replace("=", "\\=")
    |> String.replace("|", "\\|")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace(".", "\\.")
    |> String.replace("!", "\\!")
  end

  # Helper functions for conversation state management
  defp save_state(msg, extra) do
    case extract_chat_id(msg) do
      nil -> :ok
      chat_id -> ConversationState.save_state(chat_id, extra)
    end
  end

  defp clear_state(msg) do
    case extract_chat_id(msg) do
      nil -> :ok
      chat_id -> ConversationState.clear_state(chat_id)
    end
  end

  defp extract_chat_id(%{chat: %{id: id}}), do: id
  defp extract_chat_id(_), do: nil
end
