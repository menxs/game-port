import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :game, GameWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "P05HWTc99m5/jZLLXarwQDCuVT0liPzHouVaMlvViyTxCyM5GMkWlBPmH/LSM9UA",
  server: false

# In test we don't send emails.
config :game, Game.Mailer,
  adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
