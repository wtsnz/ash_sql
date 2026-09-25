# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Expectations do
  @moduledoc """
  Explicit baseline for the pinned adapters and the parent AshSQL checkout.

  New scenarios and adapters have no implicit status. A gap has a narrow error
  or wrong-result signature and a local implementation task. Updating this file
  never changes the shared scenario's expected answer.
  """

  @supported_both ~w(
    bounds.default_sort_control bounds.filter_after_limit bounds.list_filter_after_limit
    bounds.relationship_limit bounds.relationship_offset bounds.relationship_offset_only
    bounds.root_limit bounds.root_zero
    context.actor context.arguments context.attribute_tenant context.authorization
    context.authorization_bounds_control context.intermediate_action context.intermediate_actor
    context.prepared_context_control context.read_action context.shared context.through_arguments
    context.through_tenant
    field.aggregate field.calculation field.root_aggregate
    filter.exists filter.join filter.not_exists filter.or_exists filter.ordinary filter.sibling_independence
    identity.keyless_count
    loaded.avg loaded.count loaded.custom loaded.exists loaded.first loaded.list loaded.max loaded.min loaded.sum
    ordering.asc_nils_first ordering.asc_nils_last ordering.desc_nils_first ordering.desc_nils_last
    ordering.expression_first ordering.expression_list ordering.ties
    path.final_many_to_many_scalar path.many_to_many path.many_to_many_first path.many_to_many_list
    path.multi_hop path.no_attributes_control path.to_one path.unrelated
    root.avg root.count root.exists root.first root.max root.min root.sum
    use.calculation use.fanout_count use.filter use.keyset_pagination use.nested_limited_load
    use.pagination use.related_exists use.related_filter use.sort use.to_one_filter use.to_one_sort
    values.constrained_scalar values.distinct_count values.distinct_list values.field_count
    values.filtered_first_default values.include_nil_first values.include_nil_list values.list_default
    values.root_empty values.same_name_distinct_definitions values.scalar_default
    values.string_constraints values.string_name
  )

  def for(id, adapter), do: all() |> Map.fetch!(id) |> Map.fetch!(adapter)

  def all do
    Map.merge(Map.new(@supported_both, &{&1, both(:supported)}), gaps())
  end

  defp gaps do
    %{
      "root.custom" => sqlite(root_unsupported()),
      "root.list" => sqlite(root_unsupported()),
      "root.list_empty" => sqlite(root_unsupported()),
      "root.list_default_empty" => sqlite(root_unsupported()),
      "root.custom_empty" => sqlite(root_unsupported()),
      "bounds.root_custom_limit" => sqlite(root_unsupported()),
      "bounds.root_list_limit" => %{
        sqlite: root_unsupported(),
        postgres: defect_value([2, 2], "root-bounds")
      },
      "root.unsorted_first_empty" =>
        postgres(
          defect_error(
            ~r/\*\* \(KeyError\) key :sort not found in: nil/,
            "root-first"
          )
        ),
      "path.root_relationship" => %{
        sqlite:
          unsupported(
            ~r/AshSql grouped query aggregates do not yet support relationship aggregate :result/,
            "root-relationship"
          ),
        postgres:
          defect_error(
            ~r/no such aggregate field: AshSql\.Conformance\.Postgres\.Parent\.value/,
            "root-relationship"
          )
      },
      "path.final_many_to_many_first" => sqlite(many_to_many()),
      "path.final_many_to_many_list" => sqlite(many_to_many()),
      "path.final_many_to_many_custom" => sqlite(many_to_many()),
      "path.intermediate_many_to_many" => sqlite(many_to_many()),
      "path.repeated_many_to_many" => %{
        sqlite:
          unresolved_error(
            ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
            "path-multiplicity"
          ),
        postgres: unresolved_value(%{1 => 3, 2 => 2, 3 => 0}, "path-multiplicity")
      },
      "path.manual" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates over manual relationships/,
            "manual"
          )
        ),
      "path.no_attributes" => %{
        sqlite: no_attributes(),
        postgres:
          defect_error(
            ~r/field `result` in `select` does not exist in schema AshSql\.Conformance\.Postgres\.Child/,
            "no-attributes"
          )
      },
      "path.no_attributes_parent" => sqlite(no_attributes()),
      "filter.parent" => sqlite(parent_filter()),
      "filter.parent_unrelated" => sqlite(parent_filter()),
      "filter.parent_relationship" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
            "parent-correlation"
          )
        ),
      "filter.parent_join" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates with parent-dependent join filters/,
            "parent-correlation"
          )
        ),
      "filter.aggregate_dependency" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
            "filter-dependencies"
          )
        ),
      "filter.fanout_sum" => fanout(6),
      "filter.fanout_avg" => fanout(3.25),
      "filter.fanout_count" => fanout(3),
      "filter.fanout_list" => fanout([2, 2, 2]),
      "filter.fanout_custom" => fanout(6),
      "filter.fanout_count_records" =>
        postgres(defect_value(%{1 => 3, 2 => 0, 3 => 0}, "filter-fanout")),
      "filter.fanout_read_control" => sqlite(defect_value([11, 11, 12], "sorted-distinct-reads")),
      "use.fanout_read_page" => sqlite(defect_value({[11, 11], 2}, "sorted-distinct-reads")),
      "identity.composite_count" => sqlite(composite_count()),
      "identity.composite_fanout_count" => %{
        sqlite: composite_count(),
        postgres: defect_value(%{1 => 6, 2 => 1, 3 => 0}, "filter-fanout")
      },
      "identity.root_composite_count" => sqlite(composite_count()),
      "identity.keyless_source" =>
        sqlite(
          unsupported(
            ~r/AshSql cannot load aggregates on resources with no primary key/,
            "record-identity"
          )
        ),
      "identity.keyless_distinct" => %{
        sqlite:
          unresolved_error(
            ~r/requires a single primary key to count distinct records, but AshSql\.Conformance\.Sqlite\.Event has no primary key/,
            "keyless-identity"
          ),
        postgres: unresolved_value(%{1 => 2, 2 => 0, 3 => 0}, "keyless-identity")
      },
      "bounds.from_many" => both(defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many")),
      "bounds.default_sort" => both(defect_value(%{1 => 2, 2 => 4, 3 => nil}, "default-sort")),
      "bounds.unsorted_limit" =>
        sqlite(
          defect_error(~r/\*\* \(Exqlite.Error\) near "\)": syntax error/, "unsorted-bounds")
        ),
      "bounds.root_order_then_limit" => postgres(defect_value(2, "root-bounds")),
      "bounds.root_first_distinct_sort" => postgres(defect_value(2, "root-bounds")),
      "bounds.root_offset_only" =>
        postgres(defect_error(~r/\*\* \(BadMapError\) expected a map, got: nil/, "root-bounds")),
      "bounds.many_to_many_query_limit" =>
        both(unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api")),
      "ordering.unique_other_field" => %{
        sqlite:
          unresolved_error(
            ~r/AshSql only supports uniq list aggregates when sorting by the list aggregate field/,
            "unique-list-order"
          ),
        postgres:
          unresolved_error(
            ~r/ERROR 42P10 .*in an aggregate with DISTINCT, ORDER BY expressions must appear in argument list/,
            "unique-list-order"
          )
      },
      "context.relationship_context" =>
        both(defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context")),
      "context.relationship_context_control" =>
        both(defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context")),
      "context.authorization_before_bounds" =>
        both(defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds")),
      "context.prepared_query_arguments" =>
        postgres(
          defect_error(
            ~r/no function clause matching in Enumerable.List.reduce\/3/,
            "prepared-query"
          )
        ),
      "context.tenant_bypass" =>
        postgres(defect_value(%{1 => 3, 2 => 0, 3 => 0}, "tenant-bypass")),
      "context.bypass_sibling" => postgres(defect_value({3, 3}, "tenant-bypass")),
      "context.through_bypass" =>
        postgres(defect_value(%{1 => 3, 2 => 3, 3 => nil}, "tenant-bypass"))
    }
  end

  defp both(status), do: %{sqlite: status, postgres: status}
  defp sqlite(status), do: %{sqlite: status, postgres: :supported}
  defp postgres(status), do: %{sqlite: :supported, postgres: status}
  defp task(id), do: "GAPS.md##{id}"

  defp unsupported(pattern, id),
    do: {:unsupported, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp defect_error(pattern, id),
    do: {:known_defect, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp defect_value(value, id), do: {:known_defect, {:value, value}, task(id)}

  defp unresolved_error(pattern, id),
    do: {:unresolved, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp unresolved_value(value, id), do: {:unresolved, {:value, value}, task(id)}

  defp root_unsupported,
    do:
      {:unsupported,
       {:error, Ash.Error.Invalid,
        ~r/Data layer for AshSql\.Conformance\.Sqlite\.Child does not support using query aggregates/},
       task("root-kinds")}

  defp many_to_many,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
        "many-to-many-paths"
      )

  defp no_attributes,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates over no_attributes\? relationships/,
        "no-attributes"
      )

  defp parent_filter,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
        "parent-correlation"
      )

  defp composite_count,
    do:
      unsupported(
        ~r/requires a single primary key to count distinct records, but AshSql\.Conformance\.Sqlite\.Link has composite primary key/,
        "record-identity"
      )

  defp fanout(value) do
    %{
      sqlite:
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      postgres: defect_value(value, "filter-fanout")
    }
  end
end
