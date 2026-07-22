<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->
![Elixir CI](https://github.com/ash-project/ash_sql/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_sql.svg)](https://hex.pm/packages/ash_sql)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_sql)
[![REUSE status](https://api.reuse.software/badge/github.com/ash-project/ash_sql)](https://api.reuse.software/info/github.com/ash-project/ash_sql)


# AshSql

Shared functionality for ecto-based sql data layers.

## Installation

```elixir
def deps do
  [
    {:ash_sql, "~> 0.6.6"}
  ]
end
```

## Aggregate Strategies

`AshSql.Implementation` defaults aggregate planning to `:lateral`. SQL data
layers can override `aggregate_strategy/1` with `:grouped` when they need the
SQLite-style grouped aggregate implementation.

The grouped strategy uses adapter-provided list aggregation. Implementations
that select `:grouped` must implement `grouped_list_aggregate/2` and return the
windowed list expression for their SQL dialect. AshSQLite uses SQLite's JSON
list representation for this callback.
