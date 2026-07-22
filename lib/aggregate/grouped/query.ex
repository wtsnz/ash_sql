# SPDX-FileCopyrightText: 2024 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Aggregate.Grouped.Query do
  @moduledoc false

  import Ecto.Query, only: [from: 2, subquery: 1]

  @supported_kinds [:count, :first, :sum, :max, :min, :avg, :exists]

  def run_aggregate_query(original_query, aggregates, resource, implementation) do
    aggregates
    |> Enum.reduce_while({:ok, %{}}, fn aggregate, {:ok, acc} ->
      case run_single_aggregate(original_query, aggregate, resource, implementation) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, aggregate.name, value)}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp run_single_aggregate(_original_query, %{kind: kind}, _resource, _implementation)
       when kind not in @supported_kinds do
    {:error, "AshSql grouped query aggregates do not support #{inspect(kind)} aggregates"}
  end

  defp run_single_aggregate(
         _original_query,
         %{relationship_path: [_ | _]} = aggregate,
         _resource,
         _implementation
       ) do
    {:error,
     "AshSql grouped query aggregates do not yet support relationship aggregate #{inspect(aggregate.name)}"}
  end

  defp run_single_aggregate(
         original_query,
         %{kind: :exists} = aggregate,
         resource,
         implementation
       ) do
    with {:ok, query} <- filtered_query(original_query, aggregate, resource) do
      repo = AshSql.dynamic_repo(resource, implementation, query)
      {:ok, repo.exists?(query, AshSql.repo_opts(repo, implementation, nil, nil, resource))}
    end
  end

  defp run_single_aggregate(original_query, %{kind: :first} = aggregate, resource, implementation) do
    with {:ok, query} <- filtered_query(original_query, aggregate, resource),
         {:ok, field} <- aggregate_field(aggregate),
         {:ok, order_by} <- first_order_by(aggregate) do
      query =
        query
        |> Ecto.Query.exclude(:select)
        |> Ecto.Query.exclude(:order_by)
        |> Map.put(:windows, [])
        |> maybe_filter_first_nil_values(aggregate, field)
        |> maybe_sort_first(order_by)
        |> Ecto.Query.limit(1)
        |> Ecto.Query.select([row], field(row, ^field))

      repo = AshSql.dynamic_repo(resource, implementation, query)

      value = repo.one(query, AshSql.repo_opts(repo, implementation, nil, nil, resource))

      {:ok, maybe_default_value(value, aggregate)}
    end
  end

  defp run_single_aggregate(original_query, aggregate, resource, implementation) do
    with {:ok, query} <- filtered_query(original_query, aggregate, resource),
         {:ok, dynamic} <- aggregate_dynamic(query, aggregate, resource) do
      query =
        query
        |> aggregate_base_query()
        |> Ecto.Query.select(^%{aggregate.name => dynamic})

      repo = AshSql.dynamic_repo(resource, implementation, query)

      result =
        query
        |> repo.one(AshSql.repo_opts(repo, implementation, nil, nil, resource))
        |> Map.get(aggregate.name)

      {:ok, result}
    end
  end

  defp filtered_query(original_query, aggregate, resource) do
    case aggregate.query.filter do
      nil -> {:ok, original_query}
      %{expression: nil} -> {:ok, original_query}
      filter -> AshSql.Filter.filter(original_query, filter, resource)
    end
  end

  defp aggregate_base_query(query) do
    if query.distinct || query.limit do
      query =
        query
        |> Ecto.Query.exclude(:select)
        |> Ecto.Query.exclude(:order_by)
        |> Map.put(:windows, [])

      from(row in subquery(query), as: ^query.__ash_bindings__.root_binding)
      |> Map.put(:__ash_bindings__, query.__ash_bindings__)
    else
      query
      |> Ecto.Query.exclude(:select)
      |> Ecto.Query.exclude(:order_by)
      |> Map.put(:windows, [])
    end
  end

  defp aggregate_dynamic(query, %{kind: :count, field: nil, uniq?: true} = aggregate, resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [field] ->
        dynamic =
          Ecto.Query.dynamic(
            count(field(as(^query.__ash_bindings__.root_binding), ^field), :distinct)
          )

        {:ok, dynamic}

      [] ->
        {:error,
         "AshSql grouped query aggregate #{inspect(aggregate.name)} requires a single primary key to count distinct records, but #{inspect(resource)} has no primary key"}

      fields ->
        {:error,
         "AshSql grouped query aggregate #{inspect(aggregate.name)} requires a single primary key to count distinct records, but #{inspect(resource)} has composite primary key #{inspect(fields)}"}
    end
  end

  defp aggregate_dynamic(_query, %{kind: :count, field: nil}, _resource),
    do: {:ok, Ecto.Query.dynamic(count())}

  defp aggregate_dynamic(query, %{kind: :count} = aggregate, resource) do
    with {:ok, field} <- aggregate_field(aggregate, resource) do
      dynamic =
        if aggregate.uniq? do
          Ecto.Query.dynamic(
            count(field(as(^query.__ash_bindings__.root_binding), ^field), :distinct)
          )
        else
          Ecto.Query.dynamic(count(field(as(^query.__ash_bindings__.root_binding), ^field)))
        end

      {:ok, dynamic}
    end
  end

  defp aggregate_dynamic(query, aggregate, resource)
       when aggregate.kind in [:sum, :max, :min, :avg] do
    with {:ok, field} <- aggregate_field(aggregate, resource) do
      field_dynamic = Ecto.Query.dynamic(field(as(^query.__ash_bindings__.root_binding), ^field))

      dynamic =
        case aggregate.kind do
          :sum -> Ecto.Query.dynamic(sum(^field_dynamic))
          :max -> Ecto.Query.dynamic(max(^field_dynamic))
          :min -> Ecto.Query.dynamic(min(^field_dynamic))
          :avg -> Ecto.Query.dynamic(avg(^field_dynamic))
        end

      {:ok, maybe_type_dynamic(query, maybe_default_dynamic(dynamic, aggregate), aggregate)}
    end
  end

  defp aggregate_dynamic(_query, aggregate, _resource) do
    {:error, "AshSql grouped query aggregate #{inspect(aggregate.name)} is unsupported"}
  end

  defp aggregate_field(aggregate, resource \\ nil)

  defp aggregate_field(%{field: field}, _resource)
       when is_atom(field) and not is_nil(field) do
    {:ok, field}
  end

  defp aggregate_field(%{kind: :count, field: nil}, _resource), do: {:ok, nil}

  defp aggregate_field(%{name: name, field: field}, _resource) do
    {:error, "AshSql grouped query aggregate #{inspect(name)} cannot use field #{inspect(field)}"}
  end

  defp maybe_type_dynamic(query, dynamic, aggregate) do
    type =
      AshSql.Expr.parameterized_type(
        query.__ash_bindings__.sql_behaviour,
        aggregate.type,
        aggregate.constraints,
        :aggregate
      )

    if type do
      query.__ash_bindings__.sql_behaviour.type_expr(dynamic, type)
    else
      dynamic
    end
  end

  defp maybe_default_dynamic(dynamic, %{default_value: nil}), do: dynamic

  defp maybe_default_dynamic(dynamic, aggregate) do
    Ecto.Query.dynamic(coalesce(^dynamic, ^aggregate.default_value))
  end

  defp first_order_by(%{query: %{sort: sort}}) when sort in [nil, []], do: {:ok, []}

  defp first_order_by(%{query: %{sort: sort}} = aggregate) do
    sort
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn
      {field, order}, {:ok, acc} when is_atom(field) and is_atom(order) ->
        {:cont, {:ok, [{ecto_sort_order(order), field} | acc]}}

      field, {:ok, acc} when is_atom(field) ->
        {:cont, {:ok, [{:asc, field} | acc]}}

      invalid_sort, _acc ->
        {:halt,
         {:error,
          "AshSql grouped query first aggregate #{inspect(aggregate.name)} cannot use sort #{inspect(invalid_sort)}"}}
    end)
    |> case do
      {:ok, order_by} -> {:ok, Enum.reverse(order_by)}
      {:error, error} -> {:error, error}
    end
  end

  defp maybe_filter_first_nil_values(query, %{include_nil?: true}, _field), do: query

  defp maybe_filter_first_nil_values(query, _aggregate, field) do
    Ecto.Query.where(query, [row], not is_nil(field(row, ^field)))
  end

  defp maybe_default_value(nil, %{default_value: default_value}), do: default_value
  defp maybe_default_value(value, _aggregate), do: value

  defp maybe_sort_first(query, []), do: query
  defp maybe_sort_first(query, order_by), do: Ecto.Query.order_by(query, ^order_by)

  defp ecto_sort_order(:asc), do: :asc
  defp ecto_sort_order(:desc), do: :desc
  defp ecto_sort_order(:asc_nils_first), do: :asc_nulls_first
  defp ecto_sort_order(:asc_nils_last), do: :asc_nulls_last
  defp ecto_sort_order(:desc_nils_first), do: :desc_nulls_first
  defp ecto_sort_order(:desc_nils_last), do: :desc_nulls_last
  defp ecto_sort_order(other), do: other
end
