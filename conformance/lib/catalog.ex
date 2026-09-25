# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Catalog do
  @moduledoc false
  alias AshSql.Conformance.Scenarios

  def all do
    [
      Scenarios.Operations,
      Scenarios.Relationships,
      Scenarios.Filters,
      Scenarios.Bounds,
      Scenarios.Context
    ]
    |> Enum.flat_map(& &1.all())
    |> Enum.sort_by(& &1.id)
  end
end
