<!-- SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->

# Shared aggregate conformance

Run the same aggregate scenarios through Ash's public API on SQLite and
PostgreSQL. A scenario has one expected answer. PostgreSQL output is not the
definition of that answer.

This is a separate Mix project so AshSQL does not acquire adapter dependencies
or an adapter dependency cycle. Its `:ash_sql` dependency points at the parent
checkout. The two adapters are pinned in `mix.exs` and the full dependency set
is locked in `mix.lock`. Nothing in this directory is part of AshSQL's Hex
package or production API.

## Run

Use the Elixir and Erlang versions in the parent `.tool-versions`:

```sh
cd conformance
mise install
mise exec -- mix deps.get --check-locked
mise exec -- mix check
mise exec -- mix dialyzer
```

PostgreSQL 17 must be running. The defaults are `localhost:5432`, user
`postgres`, password `postgres`. Set `PGHOST`, `PGPORT`, `PGUSER`, and
`PGPASSWORD` to override them. `CONFORMANCE_PG_DATABASE` defaults to
`ash_sql_aggregate_conformance`. Use a dedicated test database. Setup creates
it if absent and runs only this suite's migrations. It does not drop databases
or truncate existing tables. Every scenario seeds its fixtures in a sandbox
transaction and rolls them back.

SQLite uses `tmp/aggregates.sqlite3`. An adapter is started only when selected:

```sh
CONFORMANCE_ADAPTERS=sqlite mise exec -- mix test
CONFORMANCE_ADAPTERS=postgres mise exec -- mix test
mise exec -- mix test --only scenario:filter.fanout_sum
```

The default selects both. Unknown adapter names fail immediately. All
dependencies still compile when selecting one adapter; selection controls
database startup and scenario execution. SQLite-only runs require no running
PostgreSQL server.

## Read the results

[MATRIX.md](MATRIX.md) lists the explicit expectations. Each scenario ID links
to its declaration line, including declarations that generate several cases.
The generator captures those locations from the Elixir source.

Test logs print each check's status, intended result and actual result. Known
gaps print their accepted signature as well. Only supported, matching results
say `PASS`; recorded gaps say `GAP MATCHED`, and unresolved cases say
`OBSERVATION MATCHED`. Failed checks retain the actual observation.

GitHub's job summary shows counts and expandable result tables, with failures
expanded. The formatter writes the same Markdown to `results/sqlite-postgres.md`
and full JSON to `results/sqlite-postgres.json`, or files named for the selected
adapter. CI uploads both, including on test failures. Long errors are shortened
for display; JSON retains full error details. Stack frames are kept in `details`
but excluded from the comparable observation, so source line changes do not
look like changed results. Assertions still check the original complete error.

| Status | A passing test means |
| --- | --- |
| `supported` | The operation returned the shared expected result. |
| `unsupported` | The operation raised the recorded exception with the recorded reason. |
| `known_defect` | The operation produced exactly the documented wrong result or error. |
| `unresolved` | The operation matches the recorded observation, pending a semantic/API decision. |

A green suite means these contracts still match. It does **not** mean all
features work. Correct results unexpectedly returned by an unsupported or
known-defect case fail the test until its declaration is promoted. A different
wrong value, unrelated exception, or database setup failure also fails.
Unresolved cases link to a decision and make no correctness claim. There are
no blanket skips and no automatic expected-result updates.

## Compare a PR

CI checks out the PR base in a separate worktree and runs its suite in the same
job, with the same runtime and PostgreSQL service. The base uses its own locked
dependencies and AshSQL checkout. Copied dependency/build caches reduce repeat
compilation; the base gets its own dependency directory and test database.

The comparison joins the two generated JSON reports by scenario ID and adapter.
GitHub shows added/removed checks and changed statuses, executions, intended
values, accepted signatures and actual observations. Full JSON remains an
artifact. Elixir scenarios and expectations are the source of truth; there is
no checked-in JSON snapshot to update.

The first PR establishes the initial baseline when its base has no suite. A
base test failure does not stop comparison with a passing PR; its exit code and
recorded results are shown. Missing reports are errors, and older reports that
lack actual observations are explicitly labelled. These comparisons describe
aggregate scenarios, while the main test step still gates all test failures.

No local work is required. To compare two saved reports locally:

```sh
mise exec -- mix conformance.compare \
  --base results/base/sqlite-postgres.json \
  --current results/sqlite-postgres.json
```

Changes are also written to `results/changes-sqlite-postgres.md`. CI compares
each adapter separately and includes the base commit in the summary.

## Coverage and boundaries

The catalog covers all nine aggregate kinds, root and loaded execution,
unrelated and relationship queries, to-one/to-many/many-to-many paths, multiple
hops, manual and attribute-free relationships, calculation and aggregate
fields, parent references, dependency and fanout filters, join filters,
ordering, bounds, empty/nil/default/unique results, constrained types,
read actions, arguments, actor, authorization, tenancy, shared context,
filtering, sorting, calculations and pagination.

The fixtures deliberately contain equal-valued records, duplicate filter
matches, nil values, an empty parent and shared destinations. Named resource
aggregates and ad hoc query aggregates both appear. Direct relationship-read
controls distinguish aggregate defects from broader read behavior. Explicit
null ordering avoids treating database defaults as an Ash parity contract.
Numerical helpers round floating-point and decimal aggregate values to six
decimal places for comparisons. Constrained custom scalar values retain their
struct and constraints; string whitespace and nils remain unchanged. String
preservation uses numeric record ordering so database text collations do not
change its expected result.

This is a representative scenario catalog with deliberate interaction cases,
not every possible combination. Schema-based Postgres tenancy, arbitrary
database types/functions, nested parent-stack depths, every manual callback
shape, other SQLite builds and libSQL need additional adapter-specific coverage.
SQL-shape, query-count and performance tests belong alongside the adapter.
Keep the existing adapter regression suites.

[GAPS.md](GAPS.md) records the implementation tasks and unresolved semantics.
In particular, limited many-to-many relationships need an Ash API decision:
the current relationship DSL lacks `limit`, and aggregate queries reject it.

## Extend

1. Add a scenario to the appropriate module in `lib/scenarios/`. Give it a
   stable ID, area, explicit expected value, and a public Ash operation.
   Keep fixtures and assertions independent of adapter identity.
2. Add fixtures or resource roles only as needed. `Fixtures` seeds data through
   Ash; `Resources` provides the shared SQL resource definitions. The `Adapter`
   behaviour keeps setup, sandbox lifecycle, resource mapping, and custom SQL
   implementations outside the scenario runner.
3. Declare every adapter's expectation in `Expectations`. New IDs and adapters
   have no default status. Link every gap to an entry in `GAPS.md`, specifying
   an exact wrong value or an exception class plus a narrow message pattern.
   Verify the public API and fixture before classifying a failure.
4. Run both adapters, regenerate `MATRIX.md` with `mix conformance.matrix`, and
   run `mix check`. Commit the matrix and expectation change with the scenario.

To add another data layer, implement `Adapter`, supply the same resource roles,
and list it in `Adapter.all/0`. Non-SQL adapters can provide their own resource
definitions and lifecycle; the scenario runner has no Ecto dependency. Add a
status for every existing scenario. Status helpers in `Expectations` currently
name the two SQL adapters and must be extended explicitly.

When a feature lands, run its existing scenario first. The unexpected-pass
failure identifies declarations to promote to `:supported`. Preserve the shared
expected result unless a separately documented semantic decision changes it.

## Baseline

The first baseline uses AshSQL extraction `0985b9f`, AshSQLite `46a4b86`,
AshPostgres `945073e4`, and Ash 3.33.10, with the full dependency versions in
this project's lockfile.
It intentionally excludes the separately stacked from_many and schema fixes.
The newer locked Ash version can expose behavior different from older adapter
test runs; the matrix describes this exact dependency set.

There are 130 shared scenarios and 27 runner/catalog/report tests. The run
matches all 260 adapter expectations:

| Adapter | Supported | Unsupported | Known defect | Unresolved |
| --- | ---: | ---: | ---: | ---: |
| SQLite | 94 | 24 | 8 | 4 |
| PostgreSQL | 104 | 0 | 22 | 4 |

These counts describe scenario outcomes, not distinct bugs or a percentage of
all Ash features. Several scenarios exercise the same underlying gap.

Local validation uses PostgreSQL 17.5 and the SQLite library bundled with the
locked Exqlite release. The workflow runs separate SQLite and PostgreSQL jobs
on all pull requests, including PRs whose base is another feature branch.
