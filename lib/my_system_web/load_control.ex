defmodule MySystemWeb.LoadControl do
  @moduledoc false
  use Phoenix.LiveDashboard.PageBuilder
  import MySystemWeb.CoreComponents

  @impl Phoenix.LiveDashboard.PageBuilder
  def mount(_params, _session, socket) do
    socket = assign(socket, scheduler_utilizations: [], success_values: [])
    if connected?(socket), do: MySystem.LoadControl.subscribe()
    {:ok, form_data(socket)}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def menu_link(_session, _capabilities) do
    {:ok, "Load control"}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl">
      <div class="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 class="text-2xl font-bold text-gray-800 mb-6">System Load Control</h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
          <div class="bg-gray-50 p-6 rounded-lg shadow-inner">
            <h3 class="text-lg font-semibold text-gray-700 mb-4">Configuration</h3>
            <.form for={@form} phx-submit="submit_form" class="space-y-6">
              <div>
                <.input
                  field={@form[:jobs]}
                  type="number"
                  min="0"
                  label="Active Jobs"
                  class="font-semibold"
                />
                <p class="mt-1 text-sm text-gray-600">Number of concurrent jobs to run in the system</p>
              </div>

              <div>
                <.input
                  field={@form[:schedulers_online]}
                  type="number"
                  min="1"
                  label="Active Schedulers"
                  class="font-semibold"
                />
                <p class="mt-1 text-sm text-gray-600">Number of BEAM schedulers to use (cores)</p>
              </div>

              <div>
                <.button type="submit" class="w-full justify-center">
                  Apply Settings
                </.button>
              </div>
            </.form>
          </div>

          <div class="bg-blue-50 p-6 rounded-lg shadow-inner">
            <h3 class="text-lg font-semibold text-gray-700 mb-4">System Overview</h3>
            <div class="space-y-4">
              <div>
                <h4 class="font-medium text-gray-700">Current Load</h4>
                <p class="text-2xl font-bold"><%= MySystem.LoadControl.target_load() %> jobs</p>
              </div>
              <div>
                <h4 class="font-medium text-gray-700">Schedulers Online</h4>
                <p class="text-2xl font-bold"><%= MySystem.LoadControl.num_schedulers() %> cores</p>
              </div>
              <div>
                <h4 class="font-medium text-gray-700">System Status</h4>
                <div class="flex items-center space-x-2">
                  <span class="h-3 w-3 bg-green-500 rounded-full"></span>
                  <span class="font-medium">Running</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="mb-6">
          <h3 class="text-lg font-semibold text-gray-700 mb-2">Performance Metrics</h3>
          <p class="text-sm text-gray-600 mb-4">Real-time monitoring of system performance metrics</p>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow-md p-6 mb-8">
        <h3 class="text-lg font-semibold text-gray-700 mb-4">Successful Jobs per Second</h3>
        <p class="text-sm text-gray-600 mb-4">Number of jobs completed successfully over time</p>
        <.jobs_successes_chart points={@success_values} num_points={MySystem.LoadControl.num_points()} />
      </div>

      <div class="bg-white rounded-lg shadow-md p-6">
        <h3 class="text-lg font-semibold text-gray-700 mb-4">Scheduler Utilization</h3>
        <p class="text-sm text-gray-600 mb-4">Percentage of scheduler capacity being utilized</p>
        <.scheduler_utilization_chart
          points={@scheduler_utilizations}
          num_points={MySystem.LoadControl.num_points()}
        />
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def handle_event("submit_form", params, socket) do
    with {:ok, string} <- Map.fetch(params, "schedulers_online"),
         {value, ""} <- Integer.parse(string),
         do: MySystem.LoadControl.set_num_schedulers(value)

    with {:ok, string} <- Map.fetch(params, "jobs"),
         {value, ""} <- Integer.parse(string),
         do: MySystem.LoadControl.set_load(value)

    {:noreply, form_data(socket)}
  end

  @impl Phoenix.LiveDashboard.PageBuilder
  def handle_info({:scheduler_utilizations, utilizations}, socket) do
    socket
    |> assign(:scheduler_utilizations, utilizations)
    |> then(&{:noreply, &1})
  end

  def handle_info({MySystem.LoadControl, :success_values, values}, socket),
    do: {:noreply, assign(socket, :success_values, values)}

  defp form_data(socket) do
    form =
      to_form(%{
        "schedulers_online" => MySystem.LoadControl.num_schedulers(),
        "jobs" => MySystem.LoadControl.target_load()
      })

    assign(socket, form: form)
  end

  defp scheduler_utilization_chart(assigns) do
    assigns =
      Map.merge(assigns, %{
        width: assigns.num_points,
        height: 300,
        title: "Scheduler Utilization",
        color: "#4338ca", # indigo-700
        legends: Enum.map([0, 25, 50, 75, 100], &%{title: "#{&1}%", at: &1 / 100}),
        x_label: "Time",
        y_label: "Utilization (%)"
      })

    ~H"""
    <.graph {assigns} />
    """
  end

  defp jobs_successes_chart(assigns) do
    max_rate = Enum.max(assigns.points, &>=/2, fn -> 0 end)

    order_of_magnitude =
      if max_rate < 10, do: 1, else: round(:math.pow(10, floor(:math.log10(max_rate)) - 1))

    quantized_max_rate = max(round(max_rate / order_of_magnitude) * order_of_magnitude, 1)
    step = max(quantize(quantized_max_rate / 5, order_of_magnitude), 1)

    points = Enum.map(assigns.points, &(&1 / max(max_rate, 1)))

    legends =
      0
      |> Stream.iterate(&(&1 + step))
      |> Stream.take_while(&(&1 <= max_rate))
      |> Enum.map(&%{title: human_readable_int(&1), at: &1 / max(max_rate, 1)})

    assigns =
      Map.merge(assigns, %{
        width: assigns.num_points,
        height: 300,
        title: "Successful Jobs Per Second",
        color: "#059669", # emerald-600
        legends: legends,
        points: points,
        x_label: "Time",
        y_label: "Jobs/sec"
      })

    ~H"""
    <.graph {assigns} />
    """
  end

  defp quantize(num, quant), do: round(num / quant) * quant

  defp human_readable_int(num) when num > 0 and rem(num, 1000) == 0, do: "#{div(num, 1000)}k"
  defp human_readable_int(num), do: num

  defp graph(assigns) do
    ~H"""
    <div class="bg-white rounded-lg p-4">
      <svg viewBox={"0 0 #{@width + 150} #{@height + 150}"} height={@height} class="w-full chart">
        <style>
          .title { font-size: 18px; font-weight: 600; }
          .axis-label { font-size: 14px; font-weight: 500; }
          .grid-line { stroke: #e5e7eb; }
          .tick-label { font-size: 12px; }
          .chart-line { stroke-linecap: round; stroke-linejoin: round; }
        </style>

        <g transform="translate(100, 60)">
          <!-- Title -->
          <g>
            <text
              class="title"
              text-anchor="middle"
              x={@width / 2}
              y="-30"
              fill="#1f2937"
            >
              {@title}
            </text>
          </g>

          <!-- Y-axis label -->
          <g>
            <text
              class="axis-label"
              text-anchor="middle"
              transform="rotate(-90)"
              x={-@height / 2}
              y="-70"
              fill="#4b5563"
            >
              {@y_label}
            </text>
          </g>

          <!-- X-axis label -->
          <g>
            <text
              class="axis-label"
              text-anchor="middle"
              x={@width / 2}
              y={@height + 40}
              fill="#4b5563"
            >
              {@x_label}
            </text>
          </g>

          <!-- Y-axis tick marks and grid lines -->
          <%= for legend <- @legends do %>
            <g>
              <text
                class="tick-label"
                text-anchor="end"
                dominant-baseline="central"
                x="-10"
                y={"#{y(legend.at, @height)}"}
                fill="#6b7280"
              >
                {legend.title}
              </text>
            </g>

            <g>
              <line
                class="grid-line"
                stroke-width="1"
                stroke-dasharray="4"
                x1="0"
                x2={@width}
                y1={"#{y(legend.at, @height)}"}
                y2={"#{y(legend.at, @height)}"}
              />
            </g>
          <% end %>

          <!-- X and Y axes -->
          <g stroke-width="2" stroke="#374151">
            <line x1="0" x2="0" y1="0" y2={@height} />
            <line x1="0" x2={@width} y1={@height} y2={@height} />
          </g>

          <!-- Data line -->
          <polyline
            class="chart-line"
            fill="none"
            stroke={@color}
            stroke-width="3"
            points={points(assigns)}
          />

          <!-- Add area under curve with gradient -->
          <defs>
            <linearGradient id={"gradient-#{@title |> String.replace(" ", "-") |> String.downcase()}"} x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color={@color} stop-opacity="0.3" />
              <stop offset="100%" stop-color={@color} stop-opacity="0.05" />
            </linearGradient>
          </defs>

          <path
            d={"M 0,#{@height} " <> points(assigns) <> " L #{@width},#{@height} Z"}
            fill={"url(#gradient-#{@title |> String.replace(" ", "-") |> String.downcase()})"}
          />
        </g>
      </svg>
    </div>
    """
  end

  defp points(assigns) do
    assigns.points
    |> moving_averages(10)
    |> Enum.with_index(1)
    |> Enum.map(fn {value, pos} ->
      x = assigns.width - pos
      "#{x},#{y(value, assigns.height)}"
    end)
    |> Enum.join(" ")
  end

  defp moving_averages(values, size) do
    values
    |> Enum.chunk_every(size, 1, :discard)
    |> Enum.map(fn list -> Enum.sum(list) / size end)
  end

  defp y(value, height), do: height - min(round(value * height), height)
end
