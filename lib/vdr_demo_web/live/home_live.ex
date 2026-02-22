defmodule VdrDemoWeb.HomeLive do
  use VdrDemoWeb, :live_view
  require Logger

  @ttl 60
  @refresh_ms 30_000
  @clients_key "clients"
  @clients_limit 20
  @clients_watch_ref :clients_watch

  def id, do: :erlang.term_to_binary(self())
  def id_to_pid(id), do: :erlang.binary_to_term(id)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Veidrodelis Demo",
        name: "",
        send_message: "",
        subscribed_topics: MapSet.new(),
        messages: [],
        next_message_id: 1,
        clients_limit: @clients_limit,
        connected_clients: [],
        client_id: nil,
        refresh_timer_ref: nil
      )

    if connected?(socket) do
      name = random_name()
      client_id = id()
      register_client(client_id, name)
      watch_clients()
      timer_ref = schedule_refresh()
      socket = assign(socket, client_id: client_id, refresh_timer_ref: timer_ref, name: name)
      socket = refresh_connected_clients(socket)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="space-y-5">
        <div class="card border border-base-300 bg-gradient-to-br from-base-100 to-base-200/40 shadow-sm">
          <div class="card-body gap-4 p-5">
            <h1 class="card-title text-2xl">Veidrodelis Demo</h1>
            <div class="grid gap-3 lg:grid-cols-[minmax(0,26rem)_auto] lg:items-end">
              <form phx-change="update_name" phx-submit="update_name" class="w-full max-w-md">
                <label class="label" for="name">Name</label>
                <input
                  id="name"
                  name="name"
                  value={@name}
                  placeholder="Your name"
                  class="input input-bordered w-full"
                  autocomplete="off"
                />
              </form>
              <div class="inline-flex items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-3 py-1 text-xs font-medium text-primary lg:justify-self-end">
                <span class="inline-block size-2 rounded-full bg-primary" />
                connected to {node()}
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-5 lg:grid-cols-3 xl:grid-cols-[1.2fr_1.2fr_1fr]">
          <section class="card h-full border border-base-300 bg-base-100 shadow-sm">
            <div class="card-body gap-5 p-5">
              <h2 class="card-title">Subscriptions</h2>
              <form phx-submit="subscribe" class="flex gap-2">
                <input
                  name="topic"
                  placeholder="Topic"
                  class="input input-bordered flex-1"
                  autocomplete="off"
                  required
                  pattern=".*\S.*"
                  title="Topic is required"
                />
                <button type="submit" class="btn btn-primary">Subscribe</button>
              </form>

              <div>
                <p class="font-semibold mb-2">Subscribed topics</p>
                <ul class="space-y-2">
                  <li :if={MapSet.size(@subscribed_topics) == 0} class="text-base-content/60 text-sm">
                    No topics yet.
                  </li>
                  <li
                    :for={topic <- Enum.sort(MapSet.to_list(@subscribed_topics))}
                    class="flex items-center justify-between rounded-md border border-base-300 px-3 py-2"
                  >
                    <span>{topic}</span>
                    <button
                      type="button"
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="unsubscribe"
                      phx-value-topic={topic}
                    >
                      x
                    </button>
                  </li>
                </ul>
              </div>

              <div>
                <p class="font-semibold mb-2">Received messages</p>
                <div class="max-h-[28rem] overflow-y-auto rounded-md border border-base-300 bg-base-200/40 p-3">
                  <div :if={Enum.empty?(@messages)} class="text-base-content/60 text-sm">
                    Messages to your subscribed topics will appear here.
                  </div>
                  <div
                    :for={message <- @messages}
                    id={"message-#{message.id}"}
                    class="chat chat-start"
                  >
                    <div class="chat-header text-xs opacity-70">
                      #{message.topic} · {message.sender}
                    </div>
                    <div class="chat-bubble">{message.body}</div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="card h-full border border-base-300 bg-base-100 shadow-sm">
            <div class="card-body gap-5 p-5">
              <h2 class="card-title">Send</h2>
              <form phx-submit="send_message" class="space-y-3">
                <input
                  name="topic"
                  placeholder="Topic"
                  class="input input-bordered w-full"
                  autocomplete="off"
                  required
                  pattern=".*\S.*"
                  title="Topic is required"
                />
                <textarea
                  name="body"
                  placeholder="Type message to send"
                  class="textarea textarea-bordered w-full min-h-44"
                ><%= @send_message %></textarea>
                <button type="submit" class="btn btn-secondary w-full">Send</button>
              </form>
            </div>
          </section>

          <section class="card h-full border border-base-300 bg-base-100 shadow-sm">
            <div class="card-body gap-3 p-5">
              <h2 class="card-title">Connected Clients</h2>
              <ul class="space-y-2">
                <li :if={Enum.empty?(@connected_clients)} class="text-base-content/60 text-sm">
                  No clients connected.
                </li>
                <li
                  :for={client <- @connected_clients}
                  class="rounded-md border border-base-300 px-3 py-2"
                >
                  <div class="font-medium">{client.name}</div>
                  <div class="text-xs text-base-content/70">{client.pid_label}</div>
                </li>
              </ul>
            </div>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_name", %{"name" => name}, socket) do
    socket = assign(socket, :name, name)

    if socket.assigns.client_id do
      register_client(socket.assigns.client_id, name)
    end

    {:noreply, socket}
  end

  def handle_event("subscribe", %{"topic" => topic}, socket) do
    topic = normalize(topic)

    register_topic(socket.assigns.client_id, topic)
    topics = MapSet.put(socket.assigns.subscribed_topics, topic)

    {:noreply, assign(socket, :subscribed_topics, topics)}
  end

  def handle_event("unsubscribe", %{"topic" => topic}, socket) do
    unregister_topic(socket.assigns.client_id, topic)
    topics = MapSet.delete(socket.assigns.subscribed_topics, topic)
    {:noreply, assign(socket, :subscribed_topics, topics)}
  end

  def handle_event("send_message", %{"topic" => topic, "body" => body}, socket) do
    topic = normalize(topic)
    body = normalize(body)
    socket = assign(socket, :send_message, body)
    fanout_topic_message(topic, body, socket.assigns.name)

    {:noreply, assign(socket, :send_message, "")}
  end

  @impl true
  def handle_info(:refresh_redis_presence, socket) do
    register_client(socket.assigns.client_id, socket.assigns.name)
    Enum.each(socket.assigns.subscribed_topics, &register_topic(socket.assigns.client_id, &1))

    {:noreply, assign(socket, :refresh_timer_ref, schedule_refresh())}
  end

  def handle_info({@clients_watch_ref, %Vdr.WatchEvent.Init{}}, socket) do
    {:noreply, refresh_connected_clients(socket)}
  end

  def handle_info({@clients_watch_ref, %Vdr.WatchEvent.Update{}}, socket) do
    {:noreply, refresh_connected_clients(socket)}
  end

  def handle_info({:topic_message, topic, body, sender}, socket) do
    message = %{
      id: socket.assigns.next_message_id,
      topic: topic,
      body: body,
      sender: sender
    }

    {:noreply,
     assign(socket,
       messages: socket.assigns.messages ++ [message],
       next_message_id: socket.assigns.next_message_id + 1
     )}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns.client_id do
      unwatch_clients()
      unregister_client(socket.assigns.client_id)
      Enum.each(socket.assigns.subscribed_topics, &unregister_topic(socket.assigns.client_id, &1))
    end

    :ok
  end

  defp normalize(value), do: value |> to_string() |> String.trim()

  defp fanout_topic_message(topic, body, sender) do
    case Veidrodelis.hkeys(:vdr, 0, topic) do
      {:ok, subscribers} ->
        subscribers
        |> Enum.each(fn subscriber_id ->
          send_to_subscriber(subscriber_id, {:topic_message, topic, body, sender})
        end)

      {:error, reason} ->
        Logger.warning("Failed to fetch subscribers for #{topic}: #{inspect(reason)}")
    end
  end

  defp send_to_subscriber(subscriber_id, message) do
    pid = id_to_pid(subscriber_id)
    send(pid, message)
  end

  defp refresh_connected_clients(socket) do
    clients =
      case Veidrodelis.hfirst(:vdr, 0, @clients_key, @clients_limit) do
        {:ok, pairs} ->
          Enum.map(pairs, fn {client_id, name} ->
            %{name: name, pid_label: pid_label(client_id)}
          end)

        {:error, reason} ->
          Logger.warning("Failed to fetch connected clients: #{inspect(reason)}")
          []
      end

    assign(socket, :connected_clients, clients)
  end

  defp pid_label(client_id) do
    try do
      client_id
      |> id_to_pid()
      |> node()
      |> to_string()
      |> then(&"@ #{&1}")
    rescue
      _ -> "@ unknown"
    end
  end

  defp watch_clients do
    case Veidrodelis.watch(:vdr, 0, @clients_key, @clients_watch_ref) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Failed to watch clients key: #{inspect(reason)}")
    end
  end

  defp unwatch_clients do
    case Veidrodelis.unwatch(:vdr, 0, @clients_key) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Failed to unwatch clients key: #{inspect(reason)}")
    end
  end

  defp register_client(nil, _name), do: :ok

  defp register_client(client_id, name) do
    redis_cmd([
      "HSETEX",
      @clients_key,
      "EX",
      Integer.to_string(@ttl),
      "FIELDS",
      "1",
      client_id,
      name
    ])
  end

  defp unregister_client(client_id), do: redis_cmd(["HDEL", @clients_key, client_id])

  defp register_topic(nil, _topic), do: :ok

  defp register_topic(client_id, topic) when is_binary(topic) do
    redis_cmd(["HSETEX", topic, "EX", Integer.to_string(@ttl), "FIELDS", "1", client_id, ""])
  end

  defp register_topic(_client_id, _topic), do: :ok

  defp unregister_topic(client_id, topic) when is_binary(topic) do
    redis_cmd(["HDEL", topic, client_id])
  end

  defp unregister_topic(_client_id, _topic), do: :ok

  defp redis_cmd(command) do
    case Redix.command(:redix, command) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Redis command failed: #{inspect(command)} #{inspect(reason)}")
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh_redis_presence, @refresh_ms)

  defp random_name do
    "user-#{Enum.random(1000..9999)}"
  end
end
