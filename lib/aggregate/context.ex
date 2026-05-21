# SPDX-FileCopyrightText: 2024 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Aggregate.Context do
  @moduledoc false

  defstruct [
    :query,
    :resource,
    :select?,
    :source_binding,
    :root_binding,
    :root_data,
    :root_data_path,
    :aggregate_path,
    :sql_behaviour,
    :tenant
  ]

  def new!(opts) do
    query = Keyword.fetch!(opts, :query)
    resource = Keyword.fetch!(opts, :resource)
    root_data = Keyword.get(opts, :root_data)

    %__MODULE__{
      query: query,
      resource: resource,
      select?: Keyword.fetch!(opts, :select?),
      source_binding: Keyword.fetch!(opts, :source_binding),
      root_binding: query.__ash_bindings__.root_binding,
      root_data: root_data,
      root_data_path: root_data_path(root_data),
      aggregate_path: Keyword.get(opts, :aggregate_path, []),
      sql_behaviour: query.__ash_bindings__.sql_behaviour,
      tenant: Keyword.get(opts, :tenant)
    }
  end

  defp root_data_path({_, path}), do: path
  defp root_data_path(_), do: []
end
