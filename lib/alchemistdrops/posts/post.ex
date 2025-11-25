defmodule Alchemistdrops.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "posts" do
    field :background, :string
    field :title, :string
    field :body, :string
    field :views, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:background, :title, :body, :views])
    |> validate_required([:background, :title, :body, :views])
  end
end
