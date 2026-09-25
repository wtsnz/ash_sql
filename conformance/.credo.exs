# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
%{
  configs: [
    %{
      name: "default",
      files: %{included: ["lib/", "test/"]},
      checks: %{disabled: [{Credo.Check.Readability.Specs, []}]}
    }
  ]
}
