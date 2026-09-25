# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenarios.Filters do
  @moduledoc false
  import AshSql.Conformance.Scenario, only: [new: 4]
  import AshSql.Conformance.Scenarios.Helpers
  require Ash.Query
  require Ash.Expr

  def all do
    [
      new("filter.ordinary", :filters, %{1 => 4, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children, field: :value, query: [filter: [visible: true]])
      end),
      new("filter.exists", :filters, %{1 => 4, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: Ash.Query.filter(ctx.child, exists(ratings, score > 5))
        )
      end),
      new("filter.aggregate_dependency", :filters, %{1 => 1, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, query: Ash.Query.filter(ctx.child, rating_count > 1))
      end),
      new("filter.parent", :filters, %{1 => 7, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: [filter: Ash.Expr.expr(value >= parent(threshold))]
        )
      end),
      new("filter.parent_relationship", :filters, %{1 => 7, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :above_threshold, field: :value)
      end),
      new("filter.parent_unrelated", :filters, %{1 => 11, 2 => 7, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, ctx.child,
          field: :value,
          query: [filter: Ash.Expr.expr(value >= parent(threshold))]
        )
      end),
      new("filter.join", :filters, %{1 => 4, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          join_filters: %{[:children] => Ash.Expr.expr(visible == true)}
        )
      end),
      new("filter.parent_join", :filters, %{1 => 7, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          join_filters: %{[:children] => Ash.Expr.expr(value >= parent(threshold))}
        )
      end),
      new("filter.fanout_count_records", :filters, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, query: Ash.Query.filter(ctx.child, ratings.score > 5))
      end),
      new("filter.fanout_read_control", :filters, [11, 12], fn ctx ->
        ctx.child
        |> Ash.Query.filter(ratings.score > 5)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("filter.sibling_independence", :filters, {4, 11}, fn ctx ->
        row =
          selected_parent(ctx)
          |> Ash.Query.aggregate(:filtered, :sum, :children,
            field: :value,
            query: [filter: [visible: true]]
          )
          |> Ash.Query.aggregate(:all, :sum, :children, field: :value)
          |> Ash.read_one!(authorize?: false)

        {row.aggregates.filtered, row.aggregates.all}
      end),
      new("filter.or_exists", :filters, %{1 => 11, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: Ash.Query.filter(ctx.child, exists(ratings, score > 5) or value == 7)
        )
      end),
      new("filter.not_exists", :filters, %{1 => 7, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: Ash.Query.filter(ctx.child, not exists(ratings, score > 5))
        )
      end)
    ] ++ fanout() ++ fanout_predicates()
  end

  defp fanout do
    for {kind, expected} <- [sum: 4, avg: 3.666667, count: 2, list: [2, 2], custom: 4] do
      new("filter.fanout_#{kind}", :filters, expected, fn ctx ->
        if kind == :avg do
          Ash.Seed.seed!(struct(ctx.adapter.resource(:rating), id: 105, child_id: 13, score: 8))
        end

        query = ctx.child |> Ash.Query.filter(ratings.score > 5) |> Ash.Query.sort(value: :asc)

        opts =
          if kind == :custom,
            do: [type: :integer, implementation: {ctx.adapter.custom_aggregate(), field: :value}],
            else: [field: :value]

        loaded(
          %{ctx | parent: selected_parent(ctx)},
          kind,
          :children,
          Keyword.put(opts, :query, query)
        )
        |> Map.fetch!(1)
      end)
    end
  end

  # Expected records match a direct read with the same filter: 11 and 12 for
  # AND, 11 to 13 for OR, 13 for NOT and 14 and 21 for the nil check. A negated
  # to-many reference matches a child with a rating that fails the predicate.
  defp fanout_predicates do
    [
      new("filter.fanout_and", :filters, %{1 => 4, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: Ash.Query.filter(ctx.child, ratings.score > 5 and value == 2)
        )
      end),
      new("filter.fanout_or", :filters, %{1 => 11, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children,
          field: :value,
          query: Ash.Query.filter(ctx.child, ratings.score > 5 or value == 7)
        )
      end),
      new("filter.fanout_not_count", :filters, %{1 => 1, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children,
          query: Ash.Query.filter(ctx.child, not (ratings.score > 5))
        )
      end),
      new("filter.fanout_nil_count", :filters, %{1 => 1, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, query: Ash.Query.filter(ctx.child, is_nil(ratings.score)))
      end)
    ]
  end
end
