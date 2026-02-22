defmodule VdrDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DNSCluster, query: Application.get_env(:vdr_demo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: VdrDemo.PubSub},
      {Redix, redix_opts()},
      %{
        id: Veidrodelis,
        start: {Veidrodelis, :start_link, [veidrodelis_opts()]}
      },
      VdrDemoWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: VdrDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VdrDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp redis_opts() do
    Application.get_env(:vdr_demo, :redis, [])
    |> Keyword.put_new(:host, "localhost")
    |> Keyword.put_new(:port, 6379)
  end

  defp redix_opts() do
    Keyword.merge(redis_opts(), name: :redix)
  end

  defp veidrodelis_opts() do
    Keyword.merge(redis_opts(),
      id: :vdr,
      ack_interval_ms: 20_000
    )
  end
end
