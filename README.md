# FirehoseX
## Firehose Rewrite (Proof of Concept) in Elixir

### FirehoseX OTP Application layout - Channel Processes Implementation

* FirehoseX Application Supervisor
  * `FirehoseX.WebServer` (Worker)
    * Cowboy web server supervision tree using `FirehoseX.Router` for routing
      incoming HTTP Long-Polling requests
    * Handle WebSocket requests via `FirehoseX.Router.WebSocket`
      (TODO - not yet implemented)
  * `FirehoseX.Channel.Supervisor` (Supervisor)
    * `FirehoseX.Channel` (worker)
      1 per active channel per cluster using global registration


This branch implements channels without using Redis for storing messages and
publishing & subcribing to their messages. When a client subscribes to a channel
that hasn't been used before, a new Channel process is started on the
handling node and registered globally in the cluster, for other nodes to find.

The benefit of this approach is simplicity in implementation, since there's
always 1 process per channel that keeps all of the required state and track of
its subscribers, while also removing the network overhead of talking to remote
Redis nodes. All channel operations are performed in memory and thus have low
latency.

Another benefit of this approach is that any single channel can't slow down
channel operations of other channels, since they all run concurrently.
In other words, if there's a very busy channel with lots of publishes and
subscribers, only that channel should slow down in terms of performance, while
all other channels keep running with their own individual load and performance
characteristics, not impacted by the busy channel.

The downside is, that in order to keep that busy channel performing well under
heavy load and not become too slow, it might be necessary to implement a separate
process pooling strategy for things like sending out messages to many subscribers,
handling incoming messages, etc.

This could easily be achieved using poolboy for managing a pool of channel worker
subscription message sender and publish handler processes.
This has not been implemented yet, and I'm not sure at what point those would
become necessary in terms of single-channel publish and subscription latencies.
A more in-depth load test would be needed to figure out the per-channel bottlenecks.
