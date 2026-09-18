defmodule AlchemistdropsWeb.CoreComponentsTest do
  use AlchemistdropsWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias AlchemistdropsWeb.CoreComponents
  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.LiveStream

  describe "flash/1" do
    test "renders info flash" do
      assigns = %{flash: %{"info" => "Test message"}, kind: :info}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash flash={@flash} kind={@kind} />
        """)

      assert html =~ "Test message"
      assert html =~ "alert-info"
    end

    test "renders error flash" do
      assigns = %{flash: %{"error" => "Error message"}, kind: :error}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash flash={@flash} kind={@kind} />
        """)

      assert html =~ "Error message"
      assert html =~ "alert-error"
    end

    test "renders flash with inner block" do
      assigns = %{flash: %{}, kind: :info}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash flash={@flash} kind={@kind}>Custom content</CoreComponents.flash>
        """)

      assert html =~ "Custom content"
    end

    test "renders flash with title" do
      assigns = %{flash: %{"info" => "Message"}, kind: :info, title: "Title"}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash flash={@flash} kind={@kind} title={@title} />
        """)

      assert html =~ "Title"
      assert html =~ "Message"
    end
  end

  describe "button/1" do
    test "renders a button element" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button>Click me</CoreComponents.button>
        """)

      assert html =~ "<button"
      assert html =~ "Click me"
      assert html =~ "btn"
    end

    test "renders a link when navigate is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button navigate="/test">Go</CoreComponents.button>
        """)

      assert html =~ "<a"
      assert html =~ "href=\"/test\""
      assert html =~ "Go"
    end

    test "renders a link when href is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button href="/external">External</CoreComponents.button>
        """)

      assert html =~ "<a"
      assert html =~ "href=\"/external\""
    end

    test "renders a link when patch is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button patch="/patch">Patch</CoreComponents.button>
        """)

      assert html =~ "<a"
      assert html =~ "href=\"/patch\""
    end

    test "renders with primary variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button variant="primary">Primary</CoreComponents.button>
        """)

      assert html =~ "btn-primary"
    end
  end

  describe "input/1" do
    test "renders text input" do
      assigns = %{form: to_form(%{"name" => "test"})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:name]} type="text" label="Name" />
        """)

      assert html =~ "input"
      assert html =~ "Name"
    end

    test "renders checkbox input" do
      assigns = %{form: to_form(%{"active" => "true"})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:active]} type="checkbox" label="Active" />
        """)

      assert html =~ "checkbox"
      assert html =~ "Active"
    end

    test "renders select input" do
      assigns = %{form: to_form(%{"status" => "active"})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[{"Active", "active"}, {"Inactive", "inactive"}]}
        />
        """)

      assert html =~ "<select"
      assert html =~ "Status"
      assert html =~ "Active"
    end

    test "renders select with prompt" do
      assigns = %{form: to_form(%{"status" => nil})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          field={@form[:status]}
          type="select"
          label="Status"
          prompt="Select one"
          options={[{"Active", "active"}]}
        />
        """)

      assert html =~ "Select one"
    end

    test "renders textarea" do
      assigns = %{form: to_form(%{"body" => "content"})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:body]} type="textarea" label="Body" />
        """)

      assert html =~ "<textarea"
      assert html =~ "Body"
    end

    test "renders input with errors" do
      changeset =
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: nil}, [:name])
        |> Ecto.Changeset.validate_required([:name])
        |> Map.put(:action, :validate)

      assigns = %{form: to_form(changeset, as: :test)}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input field={@form[:name]} type="text" label="Name" />
        """)

      assert html =~ "input-error"
    end

    test "renders multiple select" do
      assigns = %{form: to_form(%{"tags" => ["a", "b"]})}

      html =
        rendered_to_string(~H"""
        <CoreComponents.input
          field={@form[:tags]}
          type="select"
          label="Tags"
          multiple={true}
          options={[{"A", "a"}, {"B", "b"}, {"C", "c"}]}
        />
        """)

      assert html =~ "multiple"
    end
  end

  describe "header/1" do
    test "renders header with title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>Page Title</CoreComponents.header>
        """)

      assert html =~ "Page Title"
      assert html =~ "<h1"
    end

    test "renders header with subtitle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Title
          <:subtitle>Subtitle text</:subtitle>
        </CoreComponents.header>
        """)

      assert html =~ "Title"
      assert html =~ "Subtitle text"
    end

    test "renders header with actions" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Title
          <:actions>
            <button>Action</button>
          </:actions>
        </CoreComponents.header>
        """)

      assert html =~ "Title"
      assert html =~ "Action"
    end
  end

  describe "table/1" do
    test "renders table with rows" do
      assigns = %{users: [%{id: 1, name: "Alice"}, %{id: 2, name: "Bob"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "<table"
      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "Name"
    end

    test "renders table with actions" do
      assigns = %{users: [%{id: 1, name: "Alice"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users}>
          <:col :let={user} label="Name">{user.name}</:col>
          <:action :let={user}>
            <button>Edit {user.name}</button>
          </:action>
        </CoreComponents.table>
        """)

      assert html =~ "Edit Alice"
      assert html =~ "Actions"
    end

    test "renders table with row_click" do
      assigns = %{users: [%{id: 1, name: "Alice"}]}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users} row_click={&JS.navigate("/users/#{&1.id}")}>
          <:col :let={user} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "phx-click"
      assert html =~ "hover:cursor-pointer"
    end

    test "renders table with LiveStream" do
      stream = LiveStream.new(:users, 0, [], [])
      assigns = %{users: stream}

      html =
        rendered_to_string(~H"""
        <CoreComponents.table id="users" rows={@users}>
          <:col :let={{_id, user}} label="Name">{user.name}</:col>
        </CoreComponents.table>
        """)

      assert html =~ "phx-update=\"stream\""
    end
  end

  describe "list/1" do
    test "renders list" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.list>
          <:item title="Name">Alice</:item>
          <:item title="Email">alice@example.com</:item>
        </CoreComponents.list>
        """)

      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Email"
      assert html =~ "alice@example.com"
    end
  end

  describe "icon/1" do
    test "renders icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-user" />
        """)

      assert html =~ "hero-user"
    end

    test "renders icon with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-check" class="w-8 h-8" />
        """)

      assert html =~ "w-8 h-8"
    end
  end

  describe "show/1 and hide/1" do
    test "show returns JS command" do
      js = CoreComponents.show("#modal")
      assert %JS{} = js
    end

    test "hide returns JS command" do
      js = CoreComponents.hide("#modal")
      assert %JS{} = js
    end

    test "show with existing JS" do
      js = "event" |> JS.push() |> CoreComponents.show("#modal")
      assert %JS{} = js
    end

    test "hide with existing JS" do
      js = "event" |> JS.push() |> CoreComponents.hide("#modal")
      assert %JS{} = js
    end
  end

  describe "translate_error/1" do
    test "translates simple error" do
      result = CoreComponents.translate_error({"can't be blank", []})
      assert result == "can't be blank"
    end

    test "translates error with count" do
      result =
        CoreComponents.translate_error({"should be at least %{count} character(s)", [count: 3]})

      assert result =~ "3"
    end
  end

  describe "translate_errors/2" do
    test "translates errors for field" do
      errors = [name: {"can't be blank", []}, email: {"is invalid", []}]
      result = CoreComponents.translate_errors(errors, :name)
      assert result == ["can't be blank"]
    end
  end
end
