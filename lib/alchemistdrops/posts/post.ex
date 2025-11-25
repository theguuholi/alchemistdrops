defmodule Alchemistdrops.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :background, :string, default: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    field :title, :string
    field :body, :string
    field :views, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:background, :title, :body, :views])
    |> validate_required([:title, :body, :views])
  end
end
