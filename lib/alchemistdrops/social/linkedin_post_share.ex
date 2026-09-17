defmodule Alchemistdrops.Social.LinkedInPostShare do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:draft, :publishing, :published, :failed]
  @max_text_length 3_000

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "linkedin_post_shares" do
    field :status, Ecto.Enum, values: @statuses, default: :draft
    field :language, :string
    field :generated_text, :string
    field :edited_text, :string
    field :linkedin_post_urn, :string
    field :published_at, :utc_datetime
    field :error_message, :string

    belongs_to :post, Alchemistdrops.Posts.Post

    timestamps(type: :utc_datetime)
  end

  def generation_changeset(share, attrs) do
    share
    |> cast(attrs, [:language, :generated_text])
    |> put_change(:status, :draft)
    |> validate_required([:language, :generated_text])
    |> validate_length(:generated_text, max: @max_text_length)
    |> unique_constraint(:post_id)
    |> foreign_key_constraint(:post_id)
  end

  def edit_changeset(share, attrs) do
    share
    |> cast(attrs, [:edited_text])
    |> validate_length(:edited_text, max: @max_text_length)
  end

  def status_changeset(share, attrs) do
    share
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end
end
