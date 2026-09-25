# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenarios.Relationships do
  @moduledoc false
  import AshSql.Conformance.Scenario, only: [new: 4]
  import AshSql.Conformance.Scenarios.Helpers
  require Ash.Query

  def all do
    [
      new("path.to_one", :relationships, %{11 => 3, 12 => 3, 13 => 3, 14 => 3, 21 => 5}, fn ctx ->
        loaded(%{ctx | parent: ctx.child}, :sum, :parent, field: :threshold)
      end),
      new("path.multi_hop", :relationships, %{1 => 26, 2 => nil, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, [:children, :ratings], field: :score)
      end),
      new("path.many_to_many", :relationships, %{1 => 11, 2 => 3, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :tags, field: :value)
      end),
      new("path.many_to_many_list", :relationships, %{1 => [3, 8], 2 => [3], 3 => []}, fn ctx ->
        loaded(ctx, :list, :tags, field: :value, query: [sort: [value: :asc]])
      end),
      new("path.many_to_many_first", :relationships, %{1 => 8, 2 => 3, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :tags, field: :value, query: [sort: [value: :desc]])
      end),
      new(
        "path.final_many_to_many_scalar",
        :relationships,
        %{1 => 11, 2 => nil, 3 => nil},
        fn ctx ->
          loaded(ctx, :sum, [:children, :tags], field: :value)
        end
      ),
      new(
        "path.final_many_to_many_first",
        :relationships,
        %{1 => 8, 2 => nil, 3 => nil},
        fn ctx ->
          loaded(ctx, :first, [:children, :tags], field: :value, query: [sort: [value: :desc]])
        end
      ),
      new(
        "path.final_many_to_many_list",
        :relationships,
        %{1 => [3, 8], 2 => [], 3 => []},
        fn ctx ->
          loaded(ctx, :list, [:children, :tags], field: :value, query: [sort: [value: :asc]])
        end
      ),
      new(
        "path.final_many_to_many_custom",
        :relationships,
        %{1 => 11, 2 => nil, 3 => nil},
        fn ctx ->
          loaded(ctx, :custom, [:children, :tags],
            type: :integer,
            implementation: {ctx.adapter.custom_aggregate(), field: :value}
          )
        end
      ),
      new("path.intermediate_many_to_many", :relationships, %{1 => 4, 2 => 2, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, [:tags, :children], field: :value)
      end),
      new("path.repeated_many_to_many", :relationships, :unresolved, fn ctx ->
        loaded(ctx, :count, [:tags, :parents])
      end),
      new("path.unrelated", :relationships, %{1 => 5, 2 => 5, 3 => 5}, fn ctx ->
        loaded(ctx, :count, ctx.child)
      end),
      new("path.no_attributes", :relationships, %{1 => 5, 2 => 5, 3 => 5}, fn ctx ->
        loaded(ctx, :count, :all_children)
      end),
      new(
        "path.no_attributes_control",
        :relationships,
        %{1 => [11, 12, 13, 14, 21], 2 => [11, 12, 13, 14, 21], 3 => [11, 12, 13, 14, 21]},
        fn ctx ->
          relationship_ids(ctx, :all_children)
        end
      ),
      new("path.no_attributes_parent", :relationships, %{1 => 2, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :matching_children)
      end),
      new("path.manual", :relationships, %{1 => 4, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :manual_children)
      end),
      new("path.root_relationship", :relationships, 15, fn ctx ->
        Ash.aggregate!(
          ctx.parent,
          [
            {:result, :sum, path: [:children], field: :value}
          ],
          authorize?: false
        ).result
      end),
      new("identity.composite_count", :identity, %{1 => 2, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :links, uniq?: true)
      end),
      new("identity.keyless_distinct", :identity, :unresolved, fn ctx ->
        loaded(ctx, :count, :events, uniq?: true)
      end),
      new("identity.keyless_count", :identity, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :events)
      end),
      new("identity.root_composite_count", :identity, 3, fn ctx ->
        root(%{ctx | child: ctx.adapter.resource(:link)}, :count, uniq?: true)
      end),
      new("identity.composite_fanout_count", :identity, %{1 => 2, 2 => 1, 3 => 0}, fn ctx ->
        query = Ash.Query.filter(ctx.adapter.resource(:link), parent.children.value > 0)
        loaded(ctx, :count, :links, query: query)
      end),
      new("identity.keyless_source", :identity, [3, 3], fn ctx ->
        ctx.adapter.resource(:event)
        |> Ash.Query.aggregate(:result, :sum, :parent, field: :threshold)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.aggregates.result)
      end)
    ]
  end
end
