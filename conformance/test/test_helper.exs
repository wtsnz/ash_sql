# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
ExUnit.start(formatters: [ExUnit.CLIFormatter, AshSql.Conformance.Formatter])

for adapter <- AshSql.Conformance.Adapter.selected() do
  adapter.setup!()
end
