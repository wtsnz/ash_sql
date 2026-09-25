# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Matrix do
  @moduledoc false
  use Mix.Task
  @shortdoc "Generate the declared aggregate capability matrix"
  def run([]) do
    Mix.Task.run("compile")
    File.write!("MATRIX.md", AshSql.Conformance.Report.matrix())
    Mix.shell().info("Wrote MATRIX.md")
  end
end
