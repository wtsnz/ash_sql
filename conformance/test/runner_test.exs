# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.RunnerTest do
  use ExUnit.Case, async: true
  alias AshSql.Conformance.{Runner, Scenario}

  defp scenario, do: Scenario.new("example", :runner, 7, fn _ -> 7 end)

  test "supported scenarios must return the shared expected value" do
    assert Runner.assert_outcome!(scenario(), :supported, {:ok, 7})

    assert_raise ExUnit.AssertionError, ~r/expected 7, got 8/, fn ->
      Runner.assert_outcome!(scenario(), :supported, {:ok, 8})
    end
  end

  test "supported exceptions fail instead of becoming skips" do
    assert_raise ExUnit.AssertionError, ~r/raised ArgumentError/, fn ->
      Runner.assert_outcome!(scenario(), :supported, {:error, ArgumentError, "broken"})
    end
  end

  test "unsupported errors require both the exception class and message" do
    status = {:unsupported, {:error, ArgumentError, ~r/^feature unavailable$/}, "GAPS.md#example"}

    assert Runner.assert_outcome!(
             scenario(),
             status,
             {:error, ArgumentError, "feature unavailable"}
           )

    for outcome <- [
          {:error, RuntimeError, "feature unavailable"},
          {:error, ArgumentError, "database offline"}
        ] do
      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, outcome)
      end
    end
  end

  test "unexpected passes require promotion" do
    for status <- [:unsupported, :known_defect] do
      assert_raise ExUnit.AssertionError, ~r/unexpected pass/, fn ->
        Runner.assert_outcome!(scenario(), {status, {:value, 6}, "GAPS.md#example"}, {:ok, 7})
      end
    end
  end

  test "known wrong results cannot mask a different wrong result or exception" do
    status = {:known_defect, {:value, 6}, "GAPS.md#example"}
    assert Runner.assert_outcome!(scenario(), status, {:ok, 6})

    for outcome <- [{:ok, 5}, {:error, ArgumentError, "broken"}] do
      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, outcome)
      end
    end
  end

  test "unresolved semantics preserve a strict observation and a decision link" do
    status = {:unresolved, {:value, [1, 2]}, "GAPS.md#semantics"}
    assert Runner.assert_outcome!(%{scenario() | expected: :unresolved}, status, {:ok, [1, 2]})

    assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
      Runner.assert_outcome!(%{scenario() | expected: :unresolved}, status, {:ok, [2, 1]})
    end
  end

  test "all nonconforming statuses require a task or decision" do
    assert_raise ExUnit.AssertionError, ~r/link/, fn ->
      Runner.assert_outcome!(scenario(), {:known_defect, {:value, 6}, ""}, {:ok, 6})
    end
  end

  test "operation errors are captured without catching exits" do
    assert {:error, ArgumentError, "bad input"} =
             Runner.capture(fn -> raise ArgumentError, "bad input" end)

    assert catch_exit(Runner.capture(fn -> exit(:database_down) end)) == :database_down
  end
end
