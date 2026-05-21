# SPDX-FileCopyrightText: 2024 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Aggregate do
  @moduledoc false

  alias AshSql.Aggregate.Context

  def add_aggregates(
        query,
        aggregates,
        resource,
        select?,
        source_binding,
        root_data \\ nil
      )

  def add_aggregates(query, [], _resource, _select?, _source_binding, _root_data),
    do: {:ok, query}

  def add_aggregates(query, aggregates, resource, select?, source_binding, root_data) do
    context =
      Context.new!(
        query: query,
        resource: resource,
        select?: select?,
        source_binding: source_binding,
        root_data: root_data
      )

    strategy(context).add_aggregates(context, aggregates)
  end

  def extract_shared_filters(aggregates) do
    AshSql.Aggregate.Lateral.extract_shared_filters(aggregates)
  end

  def next_aggregate_name(index) do
    AshSql.Aggregate.Lateral.next_aggregate_name(index)
  end

  def can_group?(resource, aggregate, query) do
    AshSql.Aggregate.Lateral.can_group?(resource, aggregate, query)
  end

  def optimizable_first_aggregate?(resource, aggregate, query) do
    AshSql.Aggregate.Lateral.optimizable_first_aggregate?(resource, aggregate, query)
  end

  def add_subquery_aggregate_select(
        query,
        relationship_path,
        aggregate,
        resource,
        is_single?,
        first_relationship
      ) do
    AshSql.Aggregate.Lateral.add_subquery_aggregate_select(
      query,
      relationship_path,
      aggregate,
      resource,
      is_single?,
      first_relationship
    )
  end

  def aggregate_field_ref(aggregate, resource, relationship_path, query, first_relationship) do
    AshSql.Aggregate.Lateral.aggregate_field_ref(
      aggregate,
      resource,
      relationship_path,
      query,
      first_relationship
    )
  end

  def aggregate_field(aggregate, resource, query) do
    AshSql.Aggregate.Lateral.aggregate_field(aggregate, resource, query)
  end

  def wrap_in_subquery_for_aggregates(query) do
    AshSql.Aggregate.Lateral.wrap_in_subquery_for_aggregates(query)
  end

  defp strategy(%Context{} = context) do
    case context.sql_behaviour.aggregate_strategy(context.resource) do
      :lateral -> AshSql.Aggregate.Lateral
      :grouped -> AshSql.Aggregate.Grouped
    end
  end
end
