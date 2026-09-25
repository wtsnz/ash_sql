# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.AggregateTest do
  use ExUnit.Case, async: false
  alias AshSql.Conformance.{Adapter, Catalog, Expectations, Fixtures, Formatter, Runner}

  for adapter <- Adapter.selected(), scenario <- Catalog.all() do
    @tag adapter: adapter.id(), scenario: scenario.id, area: scenario.area
    test "#{adapter.id()} #{scenario.id}" do
      adapter = unquote(adapter)
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(scenario.id)))
      :ok = adapter.checkout!()

      try do
        context = Fixtures.seed!(adapter)

        Runner.run!(scenario, Expectations.for(scenario.id, adapter.id()), context, fn outcome ->
          Formatter.record(scenario.id, adapter.id(), outcome)
        end)
      after
        adapter.checkin!()
      end
    end
  end
end
