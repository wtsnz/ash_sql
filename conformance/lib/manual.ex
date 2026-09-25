# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Manual do
  @moduledoc false
  defmacro __using__(opts) do
    prefix = Keyword.fetch!(opts, :prefix)
    join_fun = String.to_atom("#{prefix}_join")
    subquery_fun = String.to_atom("#{prefix}_subquery")

    quote do
      use Ash.Resource.ManualRelationship
      import Ecto.Query

      def load(parents, _opts, %{query: query, actor: actor, authorize?: authorize?}) do
        ids = Enum.map(parents, & &1.id)

        rows =
          query
          |> Ash.Query.do_filter(parent_id: [in: ids])
          |> Ash.read!(actor: actor, authorize?: authorize?)

        {:ok, Enum.group_by(rows, & &1.parent_id)}
      end

      def unquote(join_fun)(query, _opts, parent_binding, child_binding, type, child_query) do
        {:ok,
         join(query, type, [], child in ^child_query,
           as: ^child_binding,
           on: child.parent_id == as(^parent_binding).id
         )}
      end

      def unquote(subquery_fun)(_opts, parent_binding, child_binding, child_query) do
        {:ok,
         from(row in child_query,
           where: field(as(^child_binding), :parent_id) == field(parent_as(^parent_binding), :id)
         )}
      end
    end
  end
end

defmodule AshSql.Conformance.Sqlite.Manual do
  @moduledoc false
  use AshSqlite.ManualRelationship
  use AshSql.Conformance.Manual, prefix: :ash_sqlite
end

defmodule AshSql.Conformance.Postgres.Manual do
  @moduledoc false
  use AshPostgres.ManualRelationship
  use AshSql.Conformance.Manual, prefix: :ash_postgres
end
