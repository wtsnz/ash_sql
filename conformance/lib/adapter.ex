# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Adapter do
  @moduledoc """
  Database and resource configuration for the shared aggregate scenarios.

  Scenarios receive an adapter and ask it for a resource by role. They never
  branch on the adapter ID. Other data layers can implement this contract and
  provide the same fixture domain without depending on Ecto in the runner.
  """

  @callback id() :: atom()
  @callback resource(atom()) :: module()
  @callback custom_aggregate() :: module()
  @callback setup!() :: term()
  @callback checkout!() :: term()
  @callback checkin!() :: term()

  def all, do: [AshSql.Conformance.Sqlite, AshSql.Conformance.Postgres]

  def selected do
    requested = System.get_env("CONFORMANCE_ADAPTERS", "sqlite,postgres") |> String.split(",")
    known = Map.new(all(), &{to_string(&1.id()), &1})

    Enum.map(requested, fn name ->
      Map.get(known, String.trim(name)) ||
        raise ArgumentError, "Unknown adapter: #{inspect(name)}"
    end)
    |> Enum.uniq()
  end
end

defmodule AshSql.Conformance.SqliteRepo do
  @moduledoc false
  use AshSqlite.Repo, otp_app: :ash_sql_conformance
end

defmodule AshSql.Conformance.PostgresRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_sql_conformance, warn_on_missing_ash_functions?: false
  def installed_extensions, do: []
  def min_pg_version, do: %Version{major: 17, minor: 0, patch: 0}
end

defmodule AshSql.Conformance.Sqlite do
  @moduledoc false
  @behaviour AshSql.Conformance.Adapter
  def id, do: :sqlite
  def repo, do: AshSql.Conformance.SqliteRepo

  def resource(role),
    do: Module.concat(AshSql.Conformance.Sqlite, Macro.camelize(to_string(role)))

  def custom_aggregate, do: AshSql.Conformance.SqliteSum
  def setup!, do: AshSql.Conformance.Database.setup!(repo())
  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())
end

defmodule AshSql.Conformance.Postgres do
  @moduledoc false
  @behaviour AshSql.Conformance.Adapter
  def id, do: :postgres
  def repo, do: AshSql.Conformance.PostgresRepo

  def resource(role),
    do: Module.concat(AshSql.Conformance.Postgres, Macro.camelize(to_string(role)))

  def custom_aggregate, do: AshSql.Conformance.PostgresSum
  def setup!, do: AshSql.Conformance.Database.setup!(repo())
  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())
end

defmodule AshSql.Conformance.SqliteSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
  use AshSqlite.CustomAggregate
  import Ecto.Query
  def dynamic(opts, binding), do: dynamic(sum(field(as(^binding), ^opts[:field])))
end

defmodule AshSql.Conformance.PostgresSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
  use AshPostgres.CustomAggregate
  import Ecto.Query
  def dynamic(opts, binding), do: dynamic(fragment("sum(?)", field(as(^binding), ^opts[:field])))
end
