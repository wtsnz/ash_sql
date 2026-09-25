# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.CatalogTest do
  use ExUnit.Case, async: true
  alias AshSql.Conformance.{Adapter, Catalog, Expectations, Report}

  test "every unique scenario has exactly one explicit status per adapter" do
    ids = Enum.map(Catalog.all(), & &1.id)
    assert length(ids) == length(Enum.uniq(ids))
    assert Enum.sort(ids) == Enum.sort(Map.keys(Expectations.all()))
    adapters = Adapter.all() |> Enum.map(& &1.id()) |> Enum.sort()

    for scenario <- Catalog.all() do
      statuses = Map.fetch!(Expectations.all(), scenario.id)
      assert Enum.sort(Map.keys(statuses)) == adapters

      for {_adapter, expectation} <- statuses do
        case expectation do
          :supported ->
            refute scenario.expected == :unresolved

          {:unsupported, {:error, exception, %Regex{}}, task} ->
            refute scenario.expected == :unresolved
            assert is_atom(exception) and is_binary(task)

          {:known_defect, signature, task} ->
            refute scenario.expected == :unresolved
            refute signature == {:value, scenario.expected}
            assert is_binary(task)

          {:unresolved, _signature, task} ->
            assert scenario.expected == :unresolved
            assert is_binary(task)
        end
      end
    end
  end

  test "missing scenarios and adapters cannot silently default to supported" do
    assert_raise KeyError, fn -> Expectations.for("missing", :sqlite) end
    assert_raise KeyError, fn -> Expectations.for("loaded.count", :missing) end
  end

  test "gap links resolve to a decision or implementation task" do
    headings =
      File.read!("GAPS.md")
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "## "))
      |> Enum.map(fn heading ->
        heading |> String.trim_leading("## ") |> String.downcase() |> String.replace(" ", "-")
      end)

    for %{task: task} <- Report.declaration_rows(), not is_nil(task) do
      assert "GAPS.md#" <> anchor = task
      assert anchor in headings, "Missing task: #{task}"
    end
  end

  test "the checked-in matrix matches the executable declarations" do
    assert File.read!("MATRIX.md") == Report.matrix(), "Run mix conformance.matrix"
  end
end
