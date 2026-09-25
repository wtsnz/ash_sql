# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshSql.Conformance.Resources do
  @moduledoc "One resource definition per role, instantiated for each SQL adapter."

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = Keyword.fetch!(opts, :adapter)
    parent = Module.concat(namespace, Parent)
    child = Module.concat(namespace, Child)
    rating = Module.concat(namespace, Rating)
    tag = Module.concat(namespace, Tag)
    link = Module.concat(namespace, Link)
    child_tag = Module.concat(namespace, ChildTag)
    event = Module.concat(namespace, Event)
    tenant_child = Module.concat(namespace, TenantChild)
    tenant_link = Module.concat(namespace, TenantLink)
    authorized_child = Module.concat(namespace, AuthorizedChild)
    manual = Module.concat(namespace, Manual)

    quote context: Elixir do
      defmodule unquote(parent) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_parents"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:label, :string, public?: true)
          attribute(:threshold, :integer, public?: true)
          attribute(:tenant_id, :string, public?: true)
        end

        actions do
          read :paged do
            pagination(offset?: true, countable: true, required?: false)
          end
        end

        relationships do
          has_many(:children, unquote(child), destination_attribute: :parent_id, public?: true)

          has_many(:top_children, unquote(child),
            destination_attribute: :parent_id,
            sort: [value: :desc_nils_last, id: :asc],
            limit: 2
          )

          has_many(:middle_children, unquote(child),
            destination_attribute: :parent_id,
            sort: [value: :desc_nils_last, id: :asc],
            limit: 1,
            offset: 1
          )

          has_many(:offset_children, unquote(child),
            destination_attribute: :parent_id,
            sort: [value: :desc_nils_last, id: :asc],
            offset: 1
          )

          has_many(:unsorted_limited, unquote(child), destination_attribute: :parent_id, limit: 1)

          has_one(:top_child, unquote(child),
            destination_attribute: :parent_id,
            from_many?: true,
            sort: [value: :desc_nils_last, id: :asc]
          )

          has_one(:default_top_child, unquote(child),
            destination_attribute: :parent_id,
            from_many?: true,
            default_sort: [value: :desc_nils_last, id: :asc]
          )

          has_many(:above_threshold, unquote(child),
            destination_attribute: :parent_id,
            filter: expr(value >= parent(threshold))
          )

          has_many(:all_children, unquote(child), no_attributes?: true)

          has_many(:matching_children, unquote(child),
            no_attributes?: true,
            filter: expr(value >= parent(threshold))
          )

          has_many(:manual_children, unquote(child), manual: unquote(manual))

          has_many(:visible_children, unquote(child),
            destination_attribute: :parent_id,
            read_action: :visible
          )

          has_many(:argument_children, unquote(child),
            destination_attribute: :parent_id,
            read_action: :by_label,
            read_action_arguments: %{label: "same"}
          )

          has_many(:context_children, unquote(child),
            destination_attribute: :parent_id,
            read_action: :from_context,
            relationship_context: %{visible_label: "same"}
          )

          has_many(:actor_children, unquote(child),
            destination_attribute: :parent_id,
            read_action: :for_actor
          )

          has_many(:tenant_children, unquote(tenant_child), destination_attribute: :parent_id)

          has_many(:authorized_children, unquote(authorized_child),
            destination_attribute: :parent_id
          )

          has_many(:authorized_top, unquote(authorized_child),
            destination_attribute: :parent_id,
            sort: [value: :desc_nils_last, id: :asc],
            limit: 1
          )

          has_many(:links, unquote(link), destination_attribute: :parent_id)

          has_many(:scoped_links, unquote(link),
            destination_attribute: :parent_id,
            read_action: :in_tenant,
            read_action_arguments: %{tenant_id: "a"}
          )

          has_many(:tenant_links, unquote(tenant_link), destination_attribute: :parent_id)
          has_many(:events, unquote(event), destination_attribute: :parent_id)

          many_to_many :tags, unquote(tag) do
            through(unquote(link))
            source_attribute_on_join_resource(:parent_id)
            destination_attribute_on_join_resource(:tag_id)
          end

          many_to_many :scoped_tags, unquote(tag) do
            through(unquote(link))
            join_relationship(:scoped_links)
            source_attribute_on_join_resource(:parent_id)
            destination_attribute_on_join_resource(:tag_id)
          end

          many_to_many :tenant_tags, unquote(tag) do
            through(unquote(tenant_link))
            join_relationship(:tenant_links)
            source_attribute_on_join_resource(:parent_id)
            destination_attribute_on_join_resource(:tag_id)
          end
        end

        aggregates do
          count(:child_count, :children, public?: true)
          sum(:child_sum, :children, :value, public?: true)
          first(:first_value, :children, :value, sort: [value: :asc], public?: true)
          count(:visible_count, :visible_children)
          count(:argument_count, :argument_children)
          count(:context_count, :context_children)
          count(:actor_count, :actor_children)
        end

        calculations do
          calculate(:double_threshold, :integer, expr(threshold * 2), public?: true)

          calculate(
            :sum_plus_threshold,
            :integer,
            expr(if(is_nil(child_sum), do: 0, else: child_sum) + threshold),
            public?: true
          )
        end
      end

      defmodule unquote(child) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_children"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:parent_id, :integer, public?: true)

          attribute(:label, :string,
            public?: true,
            constraints: [trim?: false, allow_empty?: true]
          )

          attribute(:value, :integer, public?: true)
          attribute(:visible, :boolean, public?: true)
          attribute(:tenant_id, :string, public?: true)
        end

        actions do
          read :visible do
            filter(expr(visible == true))
          end

          read :by_label do
            argument(:label, :string, allow_nil?: false)
            filter(expr(label == ^arg(:label)))
          end

          read :from_context do
            prepare({AshSql.Conformance.Scope, from: :context})
          end

          read :for_actor do
            prepare({AshSql.Conformance.Scope, from: :actor})
          end

          read :for_tenant do
            prepare({AshSql.Conformance.Scope, from: :tenant, field: :tenant_id})
          end
        end

        relationships do
          belongs_to(:parent, unquote(parent), define_attribute?: false, public?: true)
          has_many(:ratings, unquote(rating), destination_attribute: :child_id, public?: true)

          many_to_many :tags, unquote(tag) do
            through(unquote(child_tag))
            source_attribute_on_join_resource(:child_id)
            destination_attribute_on_join_resource(:tag_id)
          end
        end

        aggregates do
          count(:rating_count, :ratings, public?: true)
        end

        calculations do
          calculate(:double_value, :integer, expr(value * 2), public?: true)
        end
      end

      defmodule unquote(rating) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_ratings"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:child_id, :integer, public?: true)
          attribute(:score, :integer, public?: true)
        end

        relationships do
          belongs_to(:child, unquote(child), define_attribute?: false, public?: true)
        end
      end

      defmodule unquote(tag) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_tags"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:label, :string, public?: true)
          attribute(:value, :integer, public?: true)
        end

        relationships do
          many_to_many :parents, unquote(parent) do
            through(unquote(link))
            source_attribute_on_join_resource(:tag_id)
            destination_attribute_on_join_resource(:parent_id)
          end

          many_to_many :children, unquote(child) do
            through(unquote(child_tag))
            source_attribute_on_join_resource(:tag_id)
            destination_attribute_on_join_resource(:child_id)
          end
        end
      end

      defmodule unquote(link) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_links"

        attributes do
          attribute(:parent_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:tag_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:tenant_id, :string, public?: true)
        end

        relationships do
          belongs_to(:parent, unquote(parent), define_attribute?: false)
          belongs_to(:tag, unquote(tag), define_attribute?: false)
        end

        actions do
          read :in_tenant do
            argument(:tenant_id, :string, allow_nil?: false)
            filter(expr(tenant_id == ^arg(:tenant_id)))
          end
        end
      end

      defmodule unquote(child_tag) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_child_tags"

        attributes do
          attribute(:child_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:tag_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
        end
      end

      defmodule unquote(event) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_events"

        resource do
          require_primary_key?(false)
        end

        attributes do
          attribute(:parent_id, :integer, public?: true)
          attribute(:value, :integer, public?: true)
        end

        relationships do
          belongs_to(:parent, unquote(parent), define_attribute?: false)
        end
      end

      defmodule unquote(tenant_child) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_children"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:parent_id, :integer, public?: true)
          attribute(:tenant_id, :string, public?: true)
          attribute(:value, :integer, public?: true)
        end

        multitenancy do
          strategy(:attribute)
          attribute(:tenant_id)
        end
      end

      defmodule unquote(tenant_link) do
        use AshSql.Conformance.Resource, adapter: unquote(adapter), table: "ac_links"

        attributes do
          attribute(:parent_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:tag_id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:tenant_id, :string, public?: true)
        end

        multitenancy do
          strategy(:attribute)
          attribute(:tenant_id)
        end
      end

      defmodule unquote(authorized_child) do
        use AshSql.Conformance.Resource,
          adapter: unquote(adapter),
          table: "ac_children",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:parent_id, :integer, public?: true)
          attribute(:value, :integer, public?: true)
          attribute(:visible, :boolean, public?: true)
        end

        policies do
          policy action_type(:read) do
            authorize_if(expr(visible == true))
          end
        end
      end
    end
  end
end
