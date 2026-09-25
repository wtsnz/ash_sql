# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_sql_conformance,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: ["lib"],
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit, :mix]],
      aliases: [check: ["format --check-formatted", "credo --strict", "test"]]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  def cli, do: [preferred_envs: [check: :test]]

  defp deps do
    [
      {:ash_sql, path: "..", override: true},
      {:simple_sat, "~> 0.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ash_sqlite,
       git: "https://github.com/wtsnz/ash_sqlite.git",
       ref: "46a4b869450a2a961ef9af44b5b69da2d5aff29c"},
      {:ash_postgres,
       git: "https://github.com/ash-project/ash_postgres.git",
       ref: "945073e431ec6eb3fbbb831a8ce5b561d8f8cd35"}
    ]
  end
end
