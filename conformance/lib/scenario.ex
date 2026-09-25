# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenario do
  @moduledoc "A public Ash operation with an adapter-independent expected result."
  @enforce_keys [:id, :area, :expected, :run]
  defstruct [:id, :area, :expected, :run]

  def new(id, area, expected, run),
    do: %__MODULE__{id: id, area: area, expected: expected, run: run}
end

defmodule AshSql.Conformance.Runner do
  @moduledoc """
  Checks conformance or an explicitly recorded gap.

  Only the operation is captured. Database setup and fixture construction happen
  outside this boundary. Rejections require an exception class and message
  pattern; wrong-result defects require the exact observed value. An unexpected
  pass is a failure until the adapter's expectation is promoted.
  """
  import ExUnit.Assertions

  def run!(scenario, expectation, context) do
    outcome = capture(fn -> scenario.run.(context) end)
    assert_outcome!(scenario, expectation, outcome)
  end

  def assert_outcome!(scenario, :supported, {:ok, actual}) do
    assert actual == scenario.expected,
           "#{scenario.id}: expected #{format(scenario.expected)}, got #{format(actual)}"
  end

  def assert_outcome!(scenario, :supported, {:error, exception, message}) do
    flunk(
      "#{scenario.id}: expected #{format(scenario.expected)}, raised #{inspect(exception)}: #{message}"
    )
  end

  def assert_outcome!(scenario, {status, signature, task}, outcome)
      when status in [:unsupported, :known_defect, :unresolved] do
    assert is_binary(task) and byte_size(task) > 0,
           "A gap must link to an implementation task or decision"

    if status != :unresolved and outcome == {:ok, scenario.expected} do
      flunk(
        "#{scenario.id}: unexpected pass; promote this #{status} expectation to :supported (#{task})"
      )
    end

    assert matches?(signature, outcome),
           "#{scenario.id}: #{status} signature changed (#{task})\n" <>
             "Expected: #{format(signature)}\nObserved: #{format(outcome)}"
  end

  def capture(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:error, exception.__struct__, Exception.message(exception)}
  end

  defp matches?({:value, expected}, {:ok, actual}), do: expected == actual

  defp matches?({:error, exception, pattern}, {:error, exception, message}),
    do: Regex.match?(pattern, message)

  defp matches?(_, _), do: false
  defp format(value), do: inspect(value, charlists: :as_lists)
end
