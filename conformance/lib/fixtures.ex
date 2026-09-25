# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Fixtures do
  @moduledoc "Small asymmetric data sets shared by every adapter."

  def seed!(adapter) do
    parents = [
      %{id: 1, label: "alpha", threshold: 3, tenant_id: "a"},
      %{id: 2, label: "beta", threshold: 5, tenant_id: "b"},
      %{id: 3, label: "empty", threshold: 9, tenant_id: "a"}
    ]

    children = [
      %{id: 11, parent_id: 1, label: "same", value: 2, visible: true, tenant_id: "a"},
      %{id: 12, parent_id: 1, label: "same", value: 2, visible: true, tenant_id: "a"},
      %{id: 13, parent_id: 1, label: "high", value: 7, visible: false, tenant_id: "b"},
      %{id: 14, parent_id: 1, label: nil, value: nil, visible: true, tenant_id: "a"},
      %{id: 21, parent_id: 2, label: "other", value: 4, visible: true, tenant_id: "b"}
    ]

    ratings = [
      %{id: 101, child_id: 11, score: 8},
      %{id: 102, child_id: 11, score: 9},
      %{id: 103, child_id: 12, score: 8},
      %{id: 104, child_id: 13, score: 1}
    ]

    tags = [%{id: 201, label: "red", value: 3}, %{id: 202, label: "blue", value: 8}]

    links = [
      %{parent_id: 1, tag_id: 201, tenant_id: "a"},
      %{parent_id: 1, tag_id: 202, tenant_id: "b"},
      %{parent_id: 2, tag_id: 201, tenant_id: "a"}
    ]

    child_tags = [%{child_id: 11, tag_id: 201}, %{child_id: 12, tag_id: 202}]
    events = [%{parent_id: 1, value: 2}, %{parent_id: 1, value: 3}]

    for {role, rows} <- [
          parent: parents,
          child: children,
          rating: ratings,
          tag: tags,
          link: links,
          child_tag: child_tags,
          event: events
        ],
        row <- rows do
      Ash.Seed.seed!(struct(adapter.resource(role), row))
    end

    %{adapter: adapter, parent: adapter.resource(:parent), child: adapter.resource(:child)}
  end
end

defmodule AshSql.Conformance.SqliteResources do
  @moduledoc false
  use AshSql.Conformance.Resources, namespace: AshSql.Conformance.Sqlite, adapter: :sqlite
end

defmodule AshSql.Conformance.PostgresResources do
  @moduledoc false
  use AshSql.Conformance.Resources, namespace: AshSql.Conformance.Postgres, adapter: :postgres
end
