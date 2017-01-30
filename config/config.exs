# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :delta, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:delta, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
config :erlcass,
	log_level: 3,
	keyspace: "data",
	cluster_options: [
		contact_points: "10.224.45.95"
	]

# {erlcass, [
#     {log_level, 3},
#     {keyspace, <<"keyspace">>},
#     {cluster_options,[
#         {contact_points, <<"172.17.3.129,172.17.3.130,172.17.3.131">>},
#         {port, 9042},
#         {load_balance_dc_aware, {<<"dc-name">>, 0, false}},
#         {latency_aware_routing, true},
#         {token_aware_routing, true},
#         {number_threads_io, 4},
#         {queue_size_io, 128000},
#         {max_connections_host, 5},
#         {pending_requests_high_watermark, 128000},
#         {tcp_nodelay, true},
#         {tcp_keepalive, {true, 1800}},
#         {default_consistency_level, 6}
#     ]}
# ]},
