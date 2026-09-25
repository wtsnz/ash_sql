# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
import Config

config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false
config :ash, :default_string_length_count, :codepoints
config :logger, level: :warning

config :ash_sql_conformance, AshSql.Conformance.SqliteRepo,
  database: Path.expand("../tmp/aggregates.sqlite3", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2,
  migration_lock: false

config :ash_sql_conformance, AshSql.Conformance.PostgresRepo,
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  database: System.get_env("CONFORMANCE_PG_DATABASE", "ash_sql_aggregate_conformance"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2
