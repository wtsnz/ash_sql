# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenarios.Operations do
  @moduledoc false
  import AshSql.Conformance.Scenario, only: [new: 4]
  import AshSql.Conformance.Scenarios.Helpers
  require Ash.Query
  require Ash.Sort

  def all do
    loaded_kinds() ++ root_kinds() ++ semantics() ++ query_uses() ++ related_uses()
  end

  defp loaded_kinds do
    for {kind, expected, opts} <- [
          {:count, %{1 => 4, 2 => 1, 3 => 0}, []},
          {:sum, %{1 => 11, 2 => 4, 3 => nil}, [field: :value]},
          {:avg, %{1 => 3.666667, 2 => 4.0, 3 => nil}, [field: :value]},
          {:min, %{1 => 2, 2 => 4, 3 => nil}, [field: :value]},
          {:max, %{1 => 7, 2 => 4, 3 => nil}, [field: :value]},
          {:exists, %{1 => true, 2 => true, 3 => false}, []},
          {:first, %{1 => 2, 2 => 4, 3 => nil}, [field: :value, query: [sort: [value: :asc]]]},
          {:list, %{1 => [2, 2, 7], 2 => [4], 3 => []},
           [field: :value, query: [sort: [value: :asc]]]},
          {:custom, %{1 => 11, 2 => 4, 3 => nil}, []}
        ] do
      new("loaded.#{kind}", :operations, expected, fn ctx ->
        opts =
          if kind == :custom,
            do: [type: :integer, implementation: {ctx.adapter.custom_aggregate(), field: :value}],
            else: opts

        loaded(ctx, kind, :children, opts)
      end)
    end
  end

  defp root_kinds do
    for {kind, expected, opts} <- [
          {:count, 5, []},
          {:sum, 15, [field: :value]},
          {:avg, 3.75, [field: :value]},
          {:min, 2, [field: :value]},
          {:max, 7, [field: :value]},
          {:exists, true, []},
          {:first, 7, [field: :value, query: [sort: [value: :desc]]]},
          {:list, [2, 2, 4, 7], [field: :value, query: [sort: [value: :asc]]]},
          {:custom, 15, []}
        ] do
      new("root.#{kind}", :operations, expected, fn ctx ->
        opts =
          if kind == :custom,
            do: [type: :integer, implementation: {ctx.adapter.custom_aggregate(), field: :value}],
            else: opts

        root(ctx, kind, opts)
      end)
    end
  end

  defp semantics do
    [
      new("values.field_count", :results, %{1 => 3, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, field: :value)
      end),
      new("values.distinct_count", :results, %{1 => 2, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :children, field: :value, uniq?: true)
      end),
      new("values.distinct_list", :results, %{1 => [2, 7], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children, field: :value, uniq?: true, query: [sort: [value: :asc]])
      end),
      new(
        "values.include_nil_list",
        :results,
        %{1 => [nil, 2, 2, 7], 2 => [4], 3 => []},
        fn ctx ->
          loaded(ctx, :list, :children,
            field: :value,
            include_nil?: true,
            query: [sort: [value: :asc_nils_first]]
          )
        end
      ),
      new("values.include_nil_first", :results, %{1 => nil, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          include_nil?: true,
          query: [sort: [value: :asc_nils_first]]
        )
      end),
      new("values.scalar_default", :results, %{1 => 11, 2 => 4, 3 => 0}, fn ctx ->
        loaded(ctx, :sum, :children, field: :value, default: 0)
      end),
      new("values.list_default", :results, %{1 => [2, 2, 7], 2 => [4], 3 => [99]}, fn ctx ->
        loaded(ctx, :list, :children, field: :value, default: [99], query: [sort: [value: :asc]])
      end),
      new("values.filtered_first_default", :results, %{1 => 99, 2 => 99, 3 => 99}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          default: 99,
          query: [filter: [value: [gt: 100]]]
        )
      end),
      new(
        "values.constrained_scalar",
        :results,
        %{1 => quantity(11), 2 => quantity(4), 3 => quantity(0)},
        fn ctx ->
          loaded(ctx, :sum, :children,
            field: :value,
            default: 0,
            type: AshSql.Conformance.Quantity,
            constraints: [unit: :points]
          )
        end
      ),
      new(
        "values.string_constraints",
        :results,
        %{1 => ["same", "same", "high", "", " padded "], 2 => ["other"], 3 => []},
        fn ctx ->
          for {id, label} <- [{15, ""}, {16, " padded "}] do
            Ash.Seed.seed!(struct(ctx.child, id: id, parent_id: 1, label: label))
          end

          # Check string preservation independently of the database's text collation.
          loaded(ctx, :list, :children, field: :label, query: [sort: [id: :asc]])
        end
      ),
      new(
        "values.root_empty",
        :results,
        %{count: 0, sum: nil, first: nil, exists: false},
        fn ctx ->
          ctx.child
          |> Ash.Query.filter(id < 0)
          |> Ash.aggregate!(
            [
              {:count, :count},
              {:sum, :sum, field: :value},
              {:first, :first, field: :value, query: [sort: [value: :asc]]},
              {:exists, :exists}
            ],
            authorize?: false
          )
        end
      ),
      new("root.list_empty", :operations, [], fn ctx ->
        root(empty_input(ctx), :list, field: :value, query: [sort: [value: :asc]])
      end),
      new("root.list_default_empty", :operations, [99], fn ctx ->
        root(empty_input(ctx), :list,
          field: :value,
          default: [99],
          query: [sort: [value: :asc]]
        )
      end),
      new("root.custom_empty", :operations, nil, fn ctx ->
        root(empty_input(ctx), :custom,
          type: :integer,
          implementation: {ctx.adapter.custom_aggregate(), field: :value}
        )
      end),
      new("root.unsorted_first_empty", :operations, nil, fn ctx ->
        root(%{ctx | child: Ash.Query.filter(ctx.child, id < 0)}, :first, field: :value)
      end),
      new("values.same_name_distinct_definitions", :results, {11, 7}, fn ctx ->
        query =
          selected_parent(ctx) |> Ash.Query.aggregate(:total, :sum, :children, field: :value)

        original = Ash.read_one!(query, authorize?: false)

        replaced =
          query
          |> Ash.Query.aggregate(:total, :sum, :children,
            field: :value,
            query: [filter: [value: [gt: 3]]]
          )
          |> Ash.read_one!(authorize?: false)

        {original.aggregates.total, replaced.aggregates.total}
      end),
      new("values.string_name", :results, 11, fn ctx ->
        result =
          selected_parent(ctx)
          |> Ash.Query.aggregate("total", :sum, :children, field: :value)
          |> Ash.read_one!(authorize?: false)

        result.aggregates["total"]
      end)
    ] ++ null_sorts()
  end

  defp null_sorts do
    for {order, expected} <- [
          asc_nils_first: nil,
          asc_nils_last: 2,
          desc_nils_first: nil,
          desc_nils_last: 7
        ] do
      new("ordering.#{order}", :ordering, expected, fn ctx ->
        ctx = %{ctx | parent: selected_parent(ctx)}

        loaded(ctx, :first, :children,
          field: :value,
          include_nil?: true,
          query: [sort: [value: order]]
        )
        |> Map.fetch!(1)
      end)
    end
  end

  defp query_uses do
    [
      new("use.filter", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(child_sum > 5)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.sort", :usage, [2, 1, 3], fn ctx ->
        ctx.parent
        |> Ash.Query.sort(child_sum: :asc_nils_last)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.calculation", :usage, %{1 => 14, 2 => 9, 3 => 9}, fn ctx ->
        ctx.parent
        |> Ash.Query.load(:sum_plus_threshold)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{&1.id, &1.sum_plus_threshold})
      end),
      new("use.pagination", :usage, {[2], 3}, fn ctx ->
        page =
          ctx.parent
          |> Ash.Query.for_read(:paged)
          |> Ash.Query.load(:child_count)
          |> Ash.Query.sort(child_count: :desc)
          |> Ash.read!(page: [offset: 1, limit: 1, count: true], authorize?: false)

        {Enum.map(page.results, & &1.id), page.count}
      end),
      new("field.calculation", :expressions, %{1 => 22, 2 => 8, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children, field: :double_value)
      end),
      new("field.aggregate", :expressions, %{1 => 4, 2 => 0, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :children, field: :rating_count)
      end),
      new("field.root_aggregate", :expressions, 5, fn ctx ->
        Ash.aggregate!(ctx.parent, [{:result, :sum, field: :child_count}], authorize?: false).result
      end),
      new("ordering.expression_first", :ordering, %{1 => 7, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :first, :children,
          field: :value,
          query: Ash.Query.sort(ctx.child, [{Ash.Sort.expr_sort(value * -1, :integer), :asc}])
        )
      end),
      new("ordering.expression_list", :ordering, %{1 => [7, 2, 2], 2 => [4], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children,
          field: :value,
          query: Ash.Query.sort(ctx.child, [{Ash.Sort.expr_sort(value * -1, :integer), :asc}])
        )
      end),
      new("ordering.ties", :ordering, %{1 => [12, 11, 13], 2 => [21], 3 => []}, fn ctx ->
        loaded(ctx, :list, :children,
          field: :id,
          query: [filter: [value: [is_nil: false]], sort: [value: :asc, id: :desc]]
        )
      end)
    ]
  end

  # Aggregates referenced through relationships, and reads that deduplicate
  # to-many filter joins. `use.fanout_read_page` fails if duplicate joined
  # rows fill the page.
  defp related_uses do
    [
      new("use.related_filter", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(children.rating_count > 1)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.related_exists", :usage, [1], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(exists(children, rating_count > 1))
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.to_one_filter", :usage, [11, 12, 13, 14], fn ctx ->
        ctx.child
        |> Ash.Query.filter(parent.child_sum > 5)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.to_one_sort", :usage, [21, 11, 12, 13, 14], fn ctx ->
        ctx.child
        |> Ash.Query.sort([{Ash.Sort.expr_sort(parent.child_count, :integer), :asc}, id: :asc])
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("use.keyset_pagination", :usage, {[1, 2], [3]}, fn ctx ->
        query =
          ctx.parent
          |> Ash.Query.for_read(:keyset)
          |> Ash.Query.sort(child_count: :desc, id: :asc)

        first = Ash.read!(query, page: [limit: 2], authorize?: false)
        keyset = List.last(first.results).__metadata__.keyset
        next = Ash.read!(query, page: [limit: 2, after: keyset], authorize?: false)
        {Enum.map(first.results, & &1.id), Enum.map(next.results, & &1.id)}
      end),
      new(
        "use.nested_limited_load",
        :usage,
        %{1 => [{13, 1}, {11, 2}], 2 => [{21, 0}], 3 => []},
        fn ctx ->
          ctx.parent
          |> Ash.Query.load(top_children: :rating_count)
          |> Ash.read!(authorize?: false)
          |> Map.new(fn row ->
            {row.id, Enum.map(row.top_children, &{&1.id, &1.rating_count})}
          end)
        end
      ),
      new("use.fanout_count", :usage, 2, fn ctx ->
        ctx.child
        |> Ash.Query.filter(ratings.score > 5)
        |> Ash.count!(authorize?: false)
      end),
      new("use.fanout_read_page", :usage, {[11, 12], 2}, fn ctx ->
        page =
          ctx.child
          |> Ash.Query.filter(ratings.score > 5)
          |> Ash.Query.sort(id: :asc)
          |> Ash.read!(page: [limit: 2, count: true], authorize?: false)

        {Enum.map(page.results, & &1.id), page.count}
      end)
    ]
  end

  defp empty_input(ctx), do: %{ctx | child: Ash.Query.filter(ctx.child, id < 0)}

  defp quantity(value), do: %AshSql.Conformance.Quantity{value: value, unit: :points}
end
