defmodule SupercolliderCubes.ScSynth do
  @moduledoc """
  GenServer to send SuperCollider commands to the dockerized sclang instance.
  Connects to the Docker container via TCP and sends SC code strings.
  """
  use GenServer
  require Logger

  @sclang_port 57120

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_command(commands) when is_bitstring(commands) do
    GenServer.cast(__MODULE__, {:send_command, sanitize(commands)})
  end

  def send_command(commands) when is_list(commands) do
    Enum.each(commands, &send_command/1)
  end

  defp sanitize(command) do
    command
    |> String.replace(~r/\/\/.*\n/, "")
    |> String.replace(~r/[\n\r\x{001c}]/, "")
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      socket: nil,
      connected: false
    }

    # Try to connect to sclang in Docker container
    send(self(), :connect)

    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case :gen_tcp.connect(sclang_host(), @sclang_port, [:binary, active: true]) do
      {:ok, socket} ->
        Logger.info("Connected to SuperCollider in Docker container")
        Logger.info("Sending on_connection.scd...")
        send_command(sc_init_script())
        {:noreply, %{state | socket: socket, connected: true}}

      {:error, reason} ->
        Logger.warning(
          "Failed to connect to SuperCollider: #{inspect(reason)}. Retrying in 5s..."
        )

        Process.send_after(self(), :connect, 5000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:tcp, _socket, data}, state) do
    Logger.debug("SC output: #{String.trim(data)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.warning("Connection to SuperCollider closed. Reconnecting...")
    send(self(), :connect)
    {:noreply, %{state | socket: nil, connected: false}}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("TCP error: #{inspect(reason)}")
    send(self(), :connect)
    {:noreply, %{state | socket: nil, connected: false}}
  end

  @impl true
  def handle_cast({:send_command, _command}, %{socket: nil} = state) do
    Logger.warning("Cannot send command - not connected to SuperCollider")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_command, command}, %{socket: socket} = state) do
    Logger.debug("Sending command to SC: #{command}")
    :gen_tcp.send(socket, command <> "\n")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) when not is_nil(socket) do
    :gen_tcp.close(socket)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp sclang_host do
    System.get_env("SC_HOST", "localhost") |> String.to_charlist()
  end

  defp sc_init_script do
    path = Application.app_dir(:supercollider_cubes, "priv/supercollider/on_connection.scd")

    case File.read(path) do
      {:ok, body} ->
        body

      {:error, reason} ->
        Logger.error("Failed to read on_connection.scd at #{path}: #{inspect(reason)}")
        ""
    end
  end
end
