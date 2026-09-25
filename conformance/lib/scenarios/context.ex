# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Scenarios.Context do
  @moduledoc false
  import AshSql.Conformance.Scenario, only: [new: 4]
  import AshSql.Conformance.Scenarios.Helpers

  def all do
    [
      new("context.read_action", :context, %{1 => 3, 2 => 1, 3 => 0}, fn ctx ->
        named(ctx, :visible_count)
      end),
      new("context.arguments", :context, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        named(ctx, :argument_count)
      end),
      new("context.relationship_context", :context, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        named(ctx, :context_count)
      end),
      new(
        "context.relationship_context_control",
        :context,
        %{1 => [11, 12], 2 => [], 3 => []},
        fn ctx ->
          relationship_ids(ctx, :context_children)
        end
      ),
      new("context.shared", :context, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        query = Ash.Query.set_context(ctx.parent, %{shared: %{visible_label: "same"}})
        named(%{ctx | parent: query}, :context_count)
      end),
      new("context.prepared_context_control", :context, [11, 12], fn ctx ->
        ctx.child
        |> Ash.Query.set_context(%{visible_label: "same"})
        |> Ash.Query.for_read(:from_context)
        |> Ash.Query.sort(:id)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)
      end),
      new("context.actor", :context, %{1 => 2, 2 => 0, 3 => 0}, fn ctx ->
        named(ctx, :actor_count, actor: %{label: "same"})
      end),
      new("context.prepared_query_arguments", :context, %{1 => 1, 2 => 0, 3 => 0}, fn ctx ->
        query = Ash.Query.for_read(ctx.child, :by_label, %{label: "high"}, authorize?: false)
        loaded(ctx, :count, :children, query: query)
      end),
      new("context.intermediate_action", :context, %{1 => 3, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, [:argument_children, :ratings])
      end),
      new("context.intermediate_actor", :context, %{1 => 3, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, [:actor_children, :ratings], [], actor: %{label: "same"})
      end),
      new("context.attribute_tenant", :context, %{1 => 3, 2 => 0, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :tenant_children, [], tenant: "a")
      end),
      new("context.tenant_bypass", :context, %{1 => 4, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :tenant_children, [multitenancy: :bypass], tenant: "a")
      end),
      new("context.bypass_sibling", :context, {3, 4}, fn ctx ->
        row =
          selected_parent(ctx)
          |> Ash.Query.aggregate(:scoped, :count, :tenant_children)
          |> Ash.Query.aggregate(:all, :count, :tenant_children, multitenancy: :bypass)
          |> Ash.read_one!(tenant: "a", authorize?: false)

        {row.aggregates.scoped, row.aggregates.all}
      end),
      new("context.through_arguments", :context, %{1 => 3, 2 => 3, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :scoped_tags, field: :value)
      end),
      new("context.through_tenant", :context, %{1 => 3, 2 => 3, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :tenant_tags, [field: :value], tenant: "a")
      end),
      new("context.through_bypass", :context, %{1 => 11, 2 => 3, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :tenant_tags, [field: :value, multitenancy: :bypass], tenant: "a")
      end),
      new("context.authorization", :context, %{1 => 3, 2 => 1, 3 => 0}, fn ctx ->
        loaded(ctx, :count, :authorized_children, [], authorize?: true)
      end),
      new("context.authorization_before_bounds", :context, %{1 => 2, 2 => 4, 3 => nil}, fn ctx ->
        loaded(ctx, :sum, :authorized_top, [field: :value], authorize?: true)
      end),
      new(
        "context.authorization_bounds_control",
        :context,
        %{1 => [11], 2 => [21], 3 => []},
        fn ctx ->
          relationship_ids(ctx, :authorized_top, authorize?: true)
        end
      )
    ]
  end
end
