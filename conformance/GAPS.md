<!-- SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->

# Aggregate implementation and decision tasks

These are local follow-up tasks for the pinned baseline. No GitHub issue is
implied. The matrix links each nonconforming expectation to an entry below.
Unless marked as a decision, the shared scenario contains the intended result.
An observed Postgres result never replaces that result automatically.

## Root kinds

Add root SQLite custom and list aggregates. Reuse bounded root inputs,
custom expressions, windowed JSON lists, result types and defaults. An empty
input produces no window row, so apply list defaults outside the window. Promote
each kind with its empty, default and bounded scenarios.

## Root relationship

Implement root aggregation over relationship paths, preserving root scope and
endpoint fields. SQLite rejects this explicitly. The Postgres comparator also
fails the tested public `Ash.aggregate` call by resolving `value` against the
parent instead of the child. Do not assume this gap is SQLite-only.

## Root first

Postgres root `first` without an explicit sort dereferences a missing first
relationship. The empty-input scenario should return nil. Explicitly sorted
first and empty-input controls already pass.

## Many-to-many paths

Generalize grouped input construction for intermediate many-to-many hops and
first/list/custom at the end of a multi-hop path. Carry attachment identity
through each prepared through and destination input. Scalar final-hop,
single-hop list/first, empty-parent and shared-destination controls pass.

## Parent correlation

Support parent values in grouped relationship, aggregate, join and unrelated
filters. Prototype correlated scalar queries or parent-inclusive grouped input.
Keep relationship scope before bounds and aggregate predicates after them.
The public query options must hydrate parent references against the parent;
prehydrating a child query with no parent context is not equivalent.
Parent-dependent through filters and inline aggregates used in parent filters
and sorts follow the same path. Postgres returns the intended results for
both.

## Parent through load

Load many-to-many relationships whose join relationship filter uses `parent`.
Loading `same_tenant_tags` directly raises `KeyError` for `:parent_bindings`
on both adapters, and on AshSQL main. The Postgres aggregate over the same
relationship returns the intended sum, so the failure is in relationship
loading rather than aggregation.

## Manual

Support SQL-capable manual relationships using existing adapter join/subquery
callbacks where possible. The shared fixture is a normal foreign-key manual
relationship. Non-equality callbacks and nested parent aliases need further
scenarios before broader support is advertised.

## No attributes

Support grouped attribute-free relationships, separating independent inputs
from parent-dependent ones. Postgres's independent ad hoc count currently
errors on a missing selected field, while the parent-dependent count passes.
The direct relationship-load control returns all five children for each parent.

## Filter dependencies

Attach aggregate dependencies to the endpoint input before compiling its filter.
The scenarios count children with more than one rating or with any tag, and
sum children with two ratings above five. A dependency on the parent's
aggregate, through a to-one relationship, already works on SQLite. Add alias
and cycle cases as the implementation expands.

## Filter fanout

Use membership EXISTS or row-identity deduplication so filter joins do not
multiply records being aggregated. Two children with equal value 2 and three
matching ratings must sum to 4, not 6, and count as two records. The average
scenario adds a different value to expose weighting errors. Deduplicating
values is not a valid substitute for deduplicating filter matches.

A per-predicate EXISTS rewrite must keep the combined meaning of the filter.
AND and OR cases also multiply on Postgres. Their intended records, and those
of the NOT and nil-check counts, come from direct reads with the same filter.
A negated to-many reference matches a child with a rating that fails the
predicate, not a child without a matching rating. Fieldless counts already
return these records on both adapters.

SQLite rejects the affected aggregate shapes; Postgres currently returns the
multiplied sum/count/list/custom/average. The direct read control returns
distinct child records on Postgres; SQLite's duplicate is a separate read
regression, recorded under [Sorted distinct reads](#sorted-distinct-reads).
Composite-key count coverage also exposes Postgres's filter multiplication.

## Record identity

Support distinct record counts with all components of a composite key. Grouped
counts currently reject them explicitly. Include attachment keys in the
deduplication subquery. Loading aggregates on keyless source resources is also
rejected by grouped; determine which operations can use relationship keys and
which require an explicit row identity. Ordinary keyless destination counts
already work.

## Sorted distinct reads

Keep sorted SQLite reads distinct when a filter joins a to-many relationship.
This is a regression in AshSQLite #232, not an aggregate gap: upstream
AshSQLite returns the two matching children. #232 adds `return_query/2`, so
sorted DISTINCT queries go through `AshSql.Query.return_query/2`. That selects
`row_number() OVER "order"` inside the DISTINCT subquery. Postgres deduplicates
with `DISTINCT ON`, which the row number does not affect. SQLite's plain
`DISTINCT` keeps every joined row, so a sorted page of two returns child 11
twice and omits child 12 while the page count is two. Unsorted reads and
`Ash.count` are unaffected.

## From many

Respect the implicit one-row bound of `from_many?`. Both extraction strategies
currently count four children for the first parent. The separately stacked fix
is intentionally absent from this branch; merging it must cause an unexpected
pass until the expectation is promoted.

## Default sort

Apply relationship `default_sort` when there is no explicit sort. Both
aggregate paths currently choose 2 instead of 7. Direct relationship loading
returns the expected child with value 7 on both adapters.

## Unsorted bounds

Avoid an empty `ORDER BY` in grouped relationship windows. The bounded count
must be one regardless of which child is chosen; the fixture does not depend
on an unspecified ordering. SQLite currently raises a syntax error.

## Root bounds

Preserve root ordering when materializing a limited aggregate input. The
Postgres comparator discards the ordering and aggregates value 2 instead of 7.
A list's own sort also replaces the root ordering: the two highest IDs have
values 4 and nil, but Postgres lists `[2, 2]`. The unsorted custom aggregate
over the same input is correct.
An offset-only root count also raises instead of returning three. Keep root
ordering distinct from a first/list aggregate's own ordering.

## Relationship context

Make relationship context available before read preparation and avoid retaining
an earlier filter prepared without it. Both the aggregate and direct
relationship-load controls return no rows. An explicitly prepared child query
with the same context returns the two intended records, and parent shared
context also works. This needs Ash-level investigation as well as adapter work.

## Authorization bounds

Apply destination authorization before choosing limited relationship rows.
The aggregate's own predicate must remain after the bound. Both adapters return
nil for the first parent after selecting its hidden highest-valued child.
Direct authorized relationship loading returns the visible child with value 2.
Ash currently combines policy and aggregate filters, so this may require an
Ash change to preserve their distinct ordering.

## Prepared query

Retain a prepared endpoint query's action and arguments. SQLite returns the
correct count; the Postgres comparator crashes in `Enumerable.List.reduce/3`.
Configured-action and intermediate-action controls pass on both adapters.

## Tenant bypass

Honor explicit aggregate tenancy bypass on endpoints and through resources,
without changing a scoped sibling. The SQLite cases pass. Postgres returns
scoped values for these bypass cases. Investigate where Ash has already added
tenant predicates before changing adapter behavior.

## Path multiplicity

Decision: when a destination is reached through two different relationship
paths, does a fieldless count count path occurrences or distinct destinations?
The repeated many-to-many scenario currently returns three and two in Postgres;
SQLite rejects the path. These are strict observations, not accepted semantics.

## Keyless identity

Decision: define distinct-record semantics when the destination has no primary
key. PostgreSQL currently counts rows and SQLite rejects the operation. Do not
choose an arbitrary attribute, concatenate values, or assume a SQL rowid exists
for every resource.

## Many-to-many bounds API

Decision: expose relationship limits/offsets for many-to-many aggregates in Ash.
The current many-to-many DSL has no `limit` option and `Ash.Query.aggregate`
rejects a limited target query before either adapter runs. This corrects the
earlier assumption that the grouped guard alone was blocking a public feature.
Add the API and settle per-parent ordering before a conformance result is fixed.

## Unique list order

Decision: choose which occurrence supplies the ordering value when duplicate
list values have different sort keys. SQLite rejects this shape; Postgres
raises its DISTINCT/ORDER BY restriction. A representative-row rule would need
to be defined and implemented for both adapters.
