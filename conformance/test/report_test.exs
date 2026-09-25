# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.ReportTest do
  use ExUnit.Case, async: true
  alias AshSql.Conformance.Report
  alias AshSql.Conformance.Report.Comparison

  defp row(overrides \\ %{}) do
    Map.merge(
      %{
        scenario: "loaded.example",
        area: :results,
        adapter: :sqlite,
        status: :supported,
        expected: "7",
        accepted: "7",
        task: nil,
        execution: :matched,
        actual: "7"
      },
      overrides
    )
  end

  defp results(rows),
    do: %{schema_version: 1, scenarios: rows} |> Jason.encode!() |> Comparison.decode!()

  test "console prints intended and observed values and distinguishes matched gaps" do
    rows = [
      row(),
      row(%{status: :known_defect, actual: "6", accepted: "6"}),
      row(%{status: :unresolved}),
      row(%{execution: :failed, actual: "8"})
    ]

    text = Report.console(rows)
    assert text =~ "[PASS] sqlite loaded.example (supported)"
    assert text =~ "[GAP MATCHED] sqlite loaded.example (known_defect)"
    assert text =~ "[OBSERVATION MATCHED]"
    assert text =~ "[FAILED]"
    assert text =~ "intended: 7\n  observed: 8"
    assert text =~ "observed: 6\n  accepted: 6"
  end

  test "the summary escapes table and HTML content without changing string whitespace" do
    text = Report.summary([row(%{actual: "\"  padded  \" | <script>`\nnext"})], "")
    assert text =~ "\"  padded  \" &#124; &lt;script&gt;&#96;\\nnext"
    refute text =~ "<script>"
    assert text =~ "Supported checks (1)"
  end

  test "failed and excluded checks never display a pass" do
    assert Report.verdict(row(%{execution: :failed})) == "FAILED"
    assert Report.verdict(row(%{execution: :excluded})) == "EXCLUDED"
    assert Report.verdict(row(%{execution: :skipped})) == "SKIPPED"
    assert Report.summary([row(%{execution: :failed})], "") =~ "<details open>"
  end

  test "long error presentation is bounded and marked without shortening the recorded error" do
    message = String.duplicate("x", 2000)
    actual = Report.outcome({:error, ArgumentError, message})
    assert actual == "ArgumentError: " <> message
    assert Report.compact(actual, 100) == String.slice(actual, 0, 100) <> " [truncated]"
  end

  test "source line changes do not change the observed error, full details remain available" do
    first = {:error, ArgumentError, "bad input\n  (app 1.0) lib/example.ex:10: run/1"}
    second = {:error, ArgumentError, "bad input\n  (app 1.0) lib/example.ex:20: run/1"}
    assert Report.outcome(first) == Report.outcome(second)
    assert Report.observation(first).details =~ "example.ex:10"
    assert Report.observation(second).details =~ "example.ex:20"
  end

  test "invalid versions and duplicate checks are rejected" do
    assert_raise ArgumentError, ~r/Unsupported/, fn ->
      Comparison.decode!(~s({"schema_version":2,"scenarios":[]}))
    end

    assert_raise ArgumentError, ~r/Duplicate/, fn -> results([row(), row()]) end
  end

  test "promotions and changed results are visible as separate fields" do
    base = results([row(%{status: :known_defect, actual: "6", accepted: "6"})])
    current = results([row()])
    changes = Comparison.changes(base, current)
    assert [%{kind: :changed}] = changes
    markdown = Comparison.render_changes(changes)
    assert markdown =~ "| status | <code>known_defect</code> | <code>supported</code> |"
    assert markdown =~ "| actual | <code>6</code> | <code>7</code> |"
  end

  test "added and removed checks are visible, row order does not produce noise" do
    base = results([row(), row(%{scenario: "removed"})])
    current = results([row(), row(%{scenario: "added"})])
    changes = Comparison.changes(base, current)
    assert Enum.map(changes, & &1.kind) == [:added, :removed]
    assert Comparison.render_changes(changes) =~ "1 added, 1 removed, 0 changed"
    assert Comparison.changes(base, Enum.reverse(base)) == []
    assert Comparison.render_changes([]) == "No recorded result changes.\n"
  end

  test "a changed observation is detected even when declarations stay identical" do
    base = results([row()])
    current = results([row(%{execution: :failed, actual: "8"})])
    markdown = Comparison.summary(base, current, [])
    assert markdown =~ "| actual | <code>7</code> | <code>8</code> |"
    assert markdown =~ "| execution | <code>matched</code> | <code>failed</code> |"
  end

  test "checks are keyed by both scenario ID and adapter" do
    base = results([row(), row(%{adapter: :postgres})])
    current = results([row(), row(%{adapter: :postgres, actual: "8"})])
    assert [%{check: {"loaded.example", "postgres"}}] = Comparison.changes(base, current)
  end

  test "the first suite establishes a baseline without claiming improvements" do
    text = Comparison.summary(:initial, results([row()]), base_ref: "abc123")
    assert text =~ "base has no conformance suite"
    assert text =~ "initial baseline of 1 adapter checks"
    refute text =~ "added,"
  end

  test "old reports missing observations are explicit instead of assuming equality" do
    base = results([row() |> Map.drop([:actual, :accepted, :expected])])
    text = Comparison.summary(base, results([row()]), base_exit_code: 2)
    assert text =~ "Missing observations are labelled"
    assert text =~ "base suite exited with code 2"
    assert text =~ "Not recorded"
  end
end
