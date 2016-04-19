# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :console,
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:user_id]

config :firehose_ex, :web,
  port: 7474

config :firehose_ex, :channel,
  buffer_size: 100,  # default channel buffer size
  buffer_ttl:  60 * 60 * 24

config :firehose_ex, :redis,
  host: "localhost",
  port: 6379,
  password: nil,
  database: nil,
  pool: [
    size: 10,
    max_overflow: 5
  ]

# load environment specific config if it exists
# any identical config settings will override the ones specified here
env_config = "#{__DIR__}/#{Mix.env}.exs"
if File.exists?(env_config) do
  import_config env_config
end
