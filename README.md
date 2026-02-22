# Veidrodelis Demo

This is a demo project for [Veidrodelis](https://github.com/savonarola/veidrodelis).

The live demo is available at [https://veidrodelis-demo.rubybox.dev](https://veidrodelis-demo.rubybox.dev).

The project demonstrates Veidrodelis usage for shared state synchronization between multiple nodes. It a web application backed by several Elixir nodes.

When the app's (single) page is opened, a new (LiveView) client process is spawned on the node to which the user's browser is connected.

Via the UI, user may manage the client: change its name, subscribe to topics and send messages to topics. Also the head of the list of connected clients is displayed.

When a client Elixir process is spawned, it registers itself as in a Valkey hash. The subscriptions are also registered in a Valkey hash. These hashes are replicated to all nodes in the cluster.

When a message to a topic is sent, the sending client broadcasts it to all subscribers in the cluster. The subscribers are fetched locally from Veidrodelis, so messaging works without any interaction with Valkey.

> [!NOTE]
> The demo is just an example of Veidrodelis usage, it is designed to be very simple. It misses some obvious optimizations, like avoiding sending the same message to the same node multiple times or updating presence data TTL per node instead of per client.

The advantage of using Veidrodelis in such scenarios is using the same system (Valkey) as
* source of truth;
* data replication medium;
* update notification channel.

## LICENSE

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

