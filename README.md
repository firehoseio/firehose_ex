# FirehoseEx
## Firehose Rewrite (Proof of Concept) in Elixir

### FirehoseEx OTP Application layout

* FirehoseEx Application Supervisor
  * WebServer (Worker)
    * Cowboy web server supervision tree using FirehoseEx.Router for routing incoming HTTP Long-Polling requests
    * Handle WebSocket requests via FirehoseEx.Router.WebSocket (TODO - not yet implemented)
  * Redis (Supervisor)
    * Redis pools using `poolboy` with own supervision tree
      * General pool for Redis commands
      * PubSub pool for Redis PubSub
