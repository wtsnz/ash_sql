# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    allow_unregistered?(true)
  end
end

defmodule AshSql.Conformance.Resource do
  @moduledoc false

  defmacro __using__(opts) do
    adapter = Keyword.fetch!(opts, :adapter)
    table = Keyword.fetch!(opts, :table)
    authorizers = Keyword.get(opts, :authorizers, [])

    {data_layer, config} =
      case adapter do
        :sqlite ->
          {AshSqlite.DataLayer,
           quote do
             sqlite do
               table(unquote(table))
               repo(AshSql.Conformance.SqliteRepo)
             end
           end}

        :postgres ->
          {AshPostgres.DataLayer,
           quote do
             postgres do
               table(unquote(table))
               repo(AshSql.Conformance.PostgresRepo)
             end
           end}
      end

    quote do
      use Ash.Resource,
        domain: AshSql.Conformance.Domain,
        data_layer: unquote(data_layer),
        authorizers: unquote(authorizers)

      unquote(config)

      actions do
        defaults([:read])
      end
    end
  end
end

defmodule AshSql.Conformance.Scope do
  @moduledoc false
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, opts, context) do
    value =
      case opts[:from] do
        :actor -> context.actor && context.actor.label
        :context -> query.context[:visible_label]
        :tenant -> context.tenant
      end

    Ash.Query.do_filter(query, [{opts[:field] || :label, value || "missing-context"}])
  end
end

defmodule AshSql.Conformance.Quantity do
  @moduledoc false
  use Ash.Type
  defstruct [:value, :unit]
  def constraints, do: [unit: [type: :atom, default: :units]]
  def storage_type(_), do: :integer
  def cast_input(value, constraints), do: cast_stored(value, constraints)
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(%__MODULE__{} = value, _), do: {:ok, value}

  def cast_stored(value, constraints) when is_integer(value),
    do: {:ok, %__MODULE__{value: value, unit: constraints[:unit]}}

  def cast_stored(_, _), do: :error
  def dump_to_native(%__MODULE__{value: value}, _), do: {:ok, value}
  def dump_to_native(value, _) when is_integer(value) or is_nil(value), do: {:ok, value}
end
