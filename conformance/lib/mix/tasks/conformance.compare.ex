# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Compare do
  @moduledoc false
  use Mix.Task
  alias AshSql.Conformance.{Adapter, Report}
  alias AshSql.Conformance.Report.Comparison
  @shortdoc "Compare actual aggregate JSON results from two runs"

  def run(args) do
    {opts, []} =
      OptionParser.parse!(args,
        strict: [
          base: :string,
          current: :string,
          initial: :boolean,
          base_ref: :string,
          base_exit_code: :integer
        ]
      )

    Mix.Task.run("compile")
    name = Adapter.selected() |> Enum.map_join("-", & &1.id())
    current = read!(Keyword.get(opts, :current, "results/#{name}.json"))

    base =
      case {opts[:initial], opts[:base]} do
        {true, nil} -> :initial
        {value, path} when value in [false, nil] and is_binary(path) -> read!(path)
        _ -> Mix.raise("Specify --base <results.json> or --initial when the base has no suite")
      end

    comparison = Comparison.summary(base, current, opts)
    File.mkdir_p!("results")
    File.write!("results/changes-#{name}.md", comparison)
    if path = Report.summary_path(), do: File.write!(path, comparison, [:append])
    Mix.shell().info(comparison)
  end

  defp read!(path) do
    unless File.regular?(path),
      do: Mix.raise("Missing run results: #{path}; inspect the suite logs")

    path |> File.read!() |> Comparison.decode!()
  end
end
