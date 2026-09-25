# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Report.Comparison do
  @moduledoc false
  alias AshSql.Conformance.Report
  @fields ~w(status execution expected accepted actual)

  def decode!(text) do
    report = Jason.decode!(text)

    unless Map.get(report, "schema_version", 1) == 1 do
      raise ArgumentError, "Unsupported result report version"
    end

    rows = Map.fetch!(report, "scenarios")
    Enum.each(rows, &validate_row!/1)
    if map_size(index(rows)) != length(rows), do: raise(ArgumentError, "Duplicate result checks")
    rows
  end

  defp validate_row!(row) do
    for field <- ~w(scenario adapter status execution) do
      unless is_binary(row[field]), do: raise(ArgumentError, "Invalid result field: #{field}")
    end
  end

  defp index(rows), do: Map.new(rows, &{{&1["scenario"], &1["adapter"]}, &1})

  def changes(base, current) do
    base = index(base)
    current = index(current)

    (Map.keys(base) ++ Map.keys(current))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn key ->
      before = Map.get(base, key)
      after_row = Map.get(current, key)

      cond do
        is_nil(before) ->
          [%{check: key, kind: :added, before: nil, after: after_row}]

        is_nil(after_row) ->
          [%{check: key, kind: :removed, before: before, after: nil}]

        Map.take(before, @fields) != Map.take(after_row, @fields) ->
          [%{check: key, kind: :changed, before: before, after: after_row}]

        true ->
          []
      end
    end)
  end

  def summary(:initial, current, opts) do
    "## Aggregate result changes\n\nBase: #{Report.code(opts[:base_ref] || "unspecified")}. " <>
      "The base has no conformance suite. This PR establishes the initial baseline " <>
      "of #{length(current)} adapter checks; no improvements or regressions are inferred.\n"
  end

  def summary(base, current, opts) do
    missing = Enum.any?(base ++ current, &(not Map.has_key?(&1, "actual")))

    warning =
      if missing,
        do:
          "Some reports do not record actual values. Missing observations are labelled; equality of those results cannot be established.\n\n",
        else: ""

    base_status =
      if opts[:base_exit_code] && opts[:base_exit_code] != 0,
        do:
          "The base suite exited with code #{opts[:base_exit_code]}; its recorded failures are included below.\n\n",
        else: ""

    "## Aggregate result changes\n\nBase: #{Report.code(opts[:base_ref] || "supplied JSON report")}. " <>
      "Compared actual base and PR run artifacts by scenario ID and adapter. " <>
      "GAP MATCHED and matched unresolved observations do not establish feature support.\n\n" <>
      base_status <> warning <> render_changes(changes(base, current))
  end

  def render_changes([]), do: "No recorded result changes.\n"

  def render_changes(changes) do
    counts = Enum.frequencies_by(changes, & &1.kind)
    count = fn kind -> Map.get(counts, kind, 0) end
    body = Enum.map_join(changes, "\n", &change_rows/1)

    "#{count.(:added)} added, #{count.(:removed)} removed, #{count.(:changed)} changed checks.\n\n" <>
      "| Check | Changed field | Base | PR |\n| --- | --- | --- | --- |\n" <> body <> "\n"
  end

  defp change_rows(%{check: {id, adapter}, kind: :changed} = change) do
    @fields
    |> Enum.filter(&(Map.fetch(change.before, &1) != Map.fetch(change.after, &1)))
    |> Enum.map_join("\n", fn field ->
      "| #{Report.code("#{adapter} #{id}")} | #{field} | " <>
        "#{Report.code(change.before[field] || "Not recorded")} | #{Report.code(change.after[field] || "Not recorded")} |"
    end)
  end

  defp change_rows(%{check: {id, adapter}, kind: kind} = change) do
    "| #{Report.code("#{adapter} #{id}")} | #{kind} | " <>
      "#{Report.code(describe(change.before))} | #{Report.code(describe(change.after))} |"
  end

  defp describe(nil), do: "No check"

  defp describe(row),
    do: "#{row["status"]}/#{row["execution"]}; observed: #{row["actual"] || "Not recorded"}"
end
