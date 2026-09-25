# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Formatter do
  @moduledoc false
  use GenServer
  alias AshSql.Conformance.Report

  def record(id, adapter, outcome) do
    GenServer.call(__MODULE__, {:result, {id, adapter}, outcome})
  end

  def init(_opts) do
    Process.register(self(), __MODULE__)
    declarations = Map.new(Report.declaration_rows(), &{{&1.scenario, &1.adapter}, &1})
    {:ok, %{rows: [], outcomes: %{}, declarations: declarations}}
  end

  def handle_call({:result, key, outcome}, _from, state) do
    {:reply, :ok, put_in(state, [:outcomes, key], Report.observation(outcome))}
  end

  def handle_cast(
        {:test_finished, %{tags: %{scenario: id, adapter: adapter}} = test},
        state
      ) do
    key = {id, adapter}

    execution =
      case test.state do
        nil -> :matched
        {:excluded, _} -> :excluded
        {:skipped, _} -> :skipped
        _ -> :failed
      end

    row =
      state.declarations
      |> Map.fetch!(key)
      |> Map.put(:execution, execution)
      |> Map.merge(
        Map.get(state.outcomes, key, %{actual: "No operation result recorded", details: nil})
      )

    {:noreply, %{state | rows: [row | state.rows]}}
  end

  def handle_cast({:suite_finished, _times}, state) do
    Report.write_results!(state.rows)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}
end
