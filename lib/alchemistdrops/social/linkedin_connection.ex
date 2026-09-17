defmodule Alchemistdrops.Social.LinkedInConnection do
  use Ecto.Schema
  import Ecto.Changeset

  @singleton_id "personal"

  @primary_key {:id, :string, autogenerate: false}
  @type t :: %__MODULE__{
          id: String.t() | nil,
          member_urn: String.t() | nil,
          access_token_ciphertext: String.t() | nil,
          expires_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "linkedin_connections" do
    field :member_urn, :string
    field :access_token_ciphertext, :string, redact: true
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:member_urn, :access_token_ciphertext, :expires_at])
    |> put_change(:id, @singleton_id)
    |> validate_required([:member_urn, :access_token_ciphertext, :expires_at])
  end
end
