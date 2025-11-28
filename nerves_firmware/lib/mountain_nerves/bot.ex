defmodule MountainNerves.Bot do
  @bot :mountain_nerves

  use ExGram.Bot,
    name: @bot

  require Logger

  command("start")
  command("help", description: "Print the bot's help")
  command("admin", description: "Admin commands (owner only)")
  command("status", description: "Show system status (admin only)")
  command("reboot", description: "Reboot the device (admin only)")

  middleware(ExGram.Middleware.IgnoreUsername)

  def bot(), do: @bot

  ## Put here all the initizalization of the bot which will not require Internet
  def init(_opts) do
    :ok
  end

  def handle({:command, :start, msg}, context) do
    log_command("start", msg)
    answer(context, "Hi!")
  end

  def handle({:command, :help, msg}, context) do
    log_command("help", msg)
    answer(context, "Here is your help:")
  end

  def handle({:command, :admin, msg}, context) do
    log_command("admin", msg)

    if is_admin?(msg) do
      answer(
        context,
        """
        *Admin Commands*

        /status - Show system status
        /reboot - Reboot the device

        You are authorized as the bot owner.
        """,
        parse_mode: "Markdown"
      )
    else
      answer(context, "⛔ Access denied. This command is for the bot owner only.")
    end
  end

  def handle({:command, :status, msg}, context) do
    log_command("status", msg)

    if is_admin?(msg) do
      status_info = get_system_status()
      answer(context, status_info, parse_mode: "Markdown")
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

  def handle({:info, :init}, _cnt) do
    Logger.info("Init with Internet")

    user = Application.get_env(:mountain_nerves, :tg_owner_user)

    if user do
      send_ip_to_user_with_retry(user)
    end

    :ok
  end

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
    *System Status*

    *Target*: #{target}
    *Uptime*: #{uptime}
    *Memory*: #{memory}
    """

    if target == :host do
      status <> "\n_Running on host (development mode)_"
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
end
