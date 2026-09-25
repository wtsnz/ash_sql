# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenarios.Bounds do
  @moduledoc false
  import AshSql.Conformance.Scenario, only: [new: 4]
  import AshSql.Conformance.Scenarios.Helpers

  def all do
    [
      new("bounds.relationship_limit", :bounds, %{1 => 9, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :top_children, field: :value)
      end),
      new("bounds.relationship_offset", :bounds, %{1 => 2, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :middle_children, field: :value)
      end),
      new("bounds.relationship_offset_only", :bounds, %{1 => 4, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :offset_children, field: :value)
      end),
      new("bounds.filter_after_limit", :bounds, %{1 => 2, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :top_children, field: :value, query: [filter: [visible: true]])
      end),
      new("bounds.list_filter_after_limit", :bounds, %{1 => [2], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :top_children,
          field: :value,
          query: [filter: [visible: true], sort: [value: :asc]]
        )
      end),
      new("bounds.unsorted_limit", :bounds, %{1 => 1, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :unsorted_limited)
      end),
      new("bounds.from_many", :bounds, %{1 => 1, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :top_child)
      end),
      new("bounds.default_sort", :bounds, %{1 => 7, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :default_top_child, field: :value)
      end),
      new("bounds.default_sort_control", :bounds, %{1 => [13], 2 => [21], 3 => []}, fn ctx ->
        relationship_ids(ctx, :default_top_child)
      end),
      new("bounds.root_limit", :bounds, 2, fn ctx ->
        root(%{ctx | child: Ash.Query.limit(ctx.child, 2)}, :count)
      end),
      new("bounds.root_offset_only", :bounds, 3, fn ctx ->
        query = ctx.child |> Ash.Query.sort(:id) |> Ash.Query.offset(2)
        root(%{ctx | child: query}, :count)
      end),
      new("bounds.root_order_then_limit", :bounds, 7, fn ctx ->
        query = ctx.child |> Ash.Query.sort(value: :desc_nils_last) |> Ash.Query.limit(1)
        root(%{ctx | child: query}, :sum, field: :value)
      end),
      new("bounds.root_first_distinct_sort", :bounds, 7, fn ctx ->
        query = ctx.child |> Ash.Query.sort(value: :desc_nils_last) |> Ash.Query.limit(1)
        root(%{ctx | child: query}, :first, field: :value, query: [sort: [value: :asc]])
      end),
      # The two highest IDs are 21 (value 4) and 14 (value nil).
      new("bounds.root_list_limit", :bounds, [4], fn ctx ->
        query = ctx.child |> Ash.Query.sort(id: :desc) |> Ash.Query.limit(2)
        root(%{ctx | child: query}, :list, field: :value, query: [sort: [value: :asc]])
      end),
      new("bounds.root_custom_limit", :bounds, 4, fn ctx ->
        query = ctx.child |> Ash.Query.sort(id: :desc) |> Ash.Query.limit(2)

        root(%{ctx | child: query}, :custom,
          type: :integer,
          implementation: {ctx.adapter.custom_aggregate(), field: :value}
        )
      end),
      new("bounds.root_zero", :bounds, %{count: 0, first: nil, exists: false}, fn ctx ->
        ctx.child
        |> Ash.Query.limit(0)
        |> Ash.aggregate!(
          [
            {:count, :count},
            {:first, :first, field: :value, query: [sort: [value: :asc]]},
            {:exists, :exists}
          ],
          authorize?: false
        )
      end),
      new("bounds.many_to_many_query_limit", :bounds, :unresolved, fn ctx ->
        query = ctx.adapter.resource(:tag) |> Ash.Query.sort(value: :desc) |> Ash.Query.limit(1)
        loaded(ctx, :sum, :tags, field: :value, query: query)
      end),
      new("ordering.unique_other_field", :ordering, :unresolved, fn ctx ->
        loaded(ctx, :list, :children, field: :label, uniq?: true, query: [sort: [value: :desc]])
      end)
    ]
  end
end
