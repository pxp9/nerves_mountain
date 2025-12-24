defmodule MountainNerves.GraphGenerator do
  @moduledoc """
  Generates image graphs (SVG/PNG format) for trail data visualization.
  """

  alias MountainNerves.Trails
  alias Contex.{Plot, Dataset, BarChart}

  require Logger

  # Get font path at runtime (not compile time)
  defp font_path do
    :code.priv_dir(:mountain_nerves)
    |> Path.join("fonts/Roboto-Regular.ttf")
  end

  @doc """
  Generates an interannual graph and saves it to a temporary PNG file.
  Returns the file path for sending via Telegram.

  ## Examples

      iex> GraphGenerator.generate_interannual_graph(905316511)
      {:ok, "/tmp/interannual_graph_123456.png"}
  """
  def generate_interannual_graph(user_id) do
    # Get trails from the last 365 days
    from_date = DateTime.utc_now() |> DateTime.add(-365, :day)

    trails = Trails.get_trails_from_date(user_id, from_date)

    case trails do
      [] ->
        {:error, :no_data}

      trails ->
        # Group by month and calculate averages
        monthly_data = aggregate_by_month(trails)

        svg_content =
          generate_monthly_avg_svg(
            monthly_data,
            1200,
            800,
            "Interannual Summary - Monthly Average Scores"
          )

        # Extract content from {:safe, iodata} tuple and convert to string
        svg_string =
          case svg_content do
            {:safe, iodata} -> IO.iodata_to_binary(iodata)
            iodata -> IO.iodata_to_binary(iodata)
          end

        # Create temporary files
        timestamp = System.system_time(:millisecond)
        temp_svg = "/tmp/interannual_graph_#{timestamp}.svg"
        temp_png = "/tmp/interannual_graph_#{timestamp}.png"

        with :ok <- File.write(temp_svg, svg_string),
             {:ok, png_path} <- convert_svg_to_png(temp_svg, temp_png) do
          # Clean up SVG file
          File.rm(temp_svg)
          Logger.info("Graph generated successfully: #{png_path}")
          {:ok, png_path}
        else
          {:error, reason} ->
            Logger.error("Failed to generate graph: #{inspect(reason)}")
            # Clean up if files exist
            File.rm(temp_svg)
            File.rm(temp_png)
            {:error, :generation_failed}
        end
    end
  end

  # Convert SVG to PNG using Resvg (Rust-based)
  defp convert_svg_to_png(svg_path, png_path) do
    try do
      # Get the font path at runtime
      font_file = font_path()
      font_dir = Path.dirname(font_file)

      Logger.info("Converting SVG to PNG with font: #{font_file}")
      Logger.info("Font directory: #{font_dir}")

      # Check if font exists
      if File.exists?(font_file) do
        Logger.info("Font file exists")
      else
        Logger.error("Font file does not exist at: #{font_file}")
      end

      # Convert SVG to PNG using resvg with font configuration
      opts = [
        resources_dir: font_dir,
        font_files: [font_file],
        font_family: "Roboto",
        sans_serif_family: "Roboto",
        serif_family: "Roboto",
        font_size: 18,
        skip_system_fonts: true,
        dpi: 200
      ]

      # Debug: List loaded fonts
      case Resvg.list_fonts(opts) do
        {:ok, fonts} ->
          Logger.info("Loaded fonts: #{inspect(fonts)}")

        {:error, reason} ->
          Logger.warning("Failed to list fonts: #{inspect(reason)}")
      end

      case Resvg.svg_to_png(svg_path, png_path, opts) do
        :ok ->
          {:ok, png_path}

        {:error, reason} ->
          Logger.error("Failed to convert SVG to PNG: #{inspect(reason)}")
          {:error, :conversion_failed}
      end
    rescue
      e ->
        Logger.error("SVG to PNG conversion error: #{inspect(e)}")
        {:error, :conversion_error}
    end
  end

  # Aggregate trails by month and calculate average scores
  defp aggregate_by_month(trails) do
    trails
    |> Enum.group_by(fn trail ->
      # Group by year-month
      dt = trail.inserted_at
      {dt.year, dt.month}
    end)
    |> Enum.map(fn {{year, month}, month_trails} ->
      # Calculate average score for the month
      avg_score = Enum.sum(Enum.map(month_trails, & &1.score)) / length(month_trails)

      # Format as "Month Year" (e.g., "Jan 2024")
      month_str = "#{month_name(month)} #{year}"

      {month_str, avg_score, year, month}
    end)
    |> Enum.sort_by(fn {_month_str, _avg, year, month} -> {year, month} end)
  end

  # Get natural month name
  defp month_name(1), do: "Jan"
  defp month_name(2), do: "Feb"
  defp month_name(3), do: "Mar"
  defp month_name(4), do: "Apr"
  defp month_name(5), do: "May"
  defp month_name(6), do: "Jun"
  defp month_name(7), do: "Jul"
  defp month_name(8), do: "Aug"
  defp month_name(9), do: "Sep"
  defp month_name(10), do: "Oct"
  defp month_name(11), do: "Nov"
  defp month_name(12), do: "Dec"

  # Generate SVG for monthly averages
  defp generate_monthly_avg_svg(monthly_data, width, height, title) do
    # Prepare data for bar chart
    data =
      monthly_data
      |> Enum.map(fn {month_str, avg_score, _year, _month} ->
        {month_str, avg_score}
      end)

    # Create dataset
    dataset = Dataset.new(data, ["Month", "Average Score"])

    # Create plot
    plot =
      Plot.new(dataset, BarChart, width, height,
        mapping: %{category_col: "Month", value_cols: ["Average Score"]}
      )
      |> Plot.plot_options(%{})
      |> Plot.titles(title, "")
      |> Plot.axis_labels("Month", "Average Score")

    # Generate SVG
    Plot.to_svg(plot)
  end
end
