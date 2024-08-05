import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mpg, MPGWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0o+yqDohl4hBIPdpzVoIIRel8N6Y9YdEBBbasfl1OFbAYA3T87dbAQz8Nwyjz6kR",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
