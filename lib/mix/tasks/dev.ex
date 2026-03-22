defmodule Mix.Tasks.Dev do
  @shortdoc "Starts the full dev environment (SuperCollider container + Phoenix server)"

  @moduledoc """
  Rebuilds (if necessary) and starts the SuperCollider container, then starts the Phoenix server.

      $ mix dev

  Docker's build cache means the container image is only rebuilt when the Dockerfile
  or files in the supercollider/ directory have changed.
  """

  use Mix.Task

  @compose_dir "."

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("==> Starting SuperCollider container...")

    case docker_compose(["up", "supercollider", "--build", "--detach"]) do
      0 ->
        Mix.shell().info("==> SuperCollider container is up")
        Mix.shell().info("==> Starting Phoenix server (SC logs interleaved)...")
        Task.start(fn -> stream_sc_logs() end)

        System.at_exit(fn _ ->
          Mix.shell().info("==> Stopping SuperCollider container...")
          docker_compose(["down"])
        end)

        Mix.Task.run("phx.server")

      code ->
        Mix.raise("docker compose failed with exit code #{code}")
    end
  end

  # cyan [SC] prefix for each docker log line
  @sc_prefix IO.ANSI.cyan() <> "[SC] " <> IO.ANSI.reset()

  defp stream_sc_logs do
    port =
      Port.open(
        {:spawn_executable, System.find_executable("docker")},
        [:stream, :line, :exit_status,
         args: ["compose", "logs", "supercollider", "--follow", "--no-log-prefix"],
         cd: @compose_dir]
      )

    stream_port(port)
  end

  defp stream_port(port) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        IO.puts(@sc_prefix <> IO.chardata_to_string(line))
        stream_port(port)

      {^port, {:exit_status, _}} ->
        :ok
    end
  end

  defp docker_compose(args) do
    {_, exit_code} =
      System.cmd("docker", ["compose"] ++ args,
        cd: @compose_dir,
        into: IO.stream(:stdio, :line)
      )

    exit_code
  end
end
