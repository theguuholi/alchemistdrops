defmodule Alchemistdrops.Repo.Migrations.CreateLinkedinSocialTables do
  use Ecto.Migration

  def change do
    create table(:linkedin_connections, primary_key: false) do
      add :id, :string, primary_key: true
      add :member_urn, :string, null: false
      add :access_token_ciphertext, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create constraint(:linkedin_connections, :linkedin_connections_personal_id_check,
             check: "id = 'personal'"
           )

    create table(:linkedin_post_shares, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "draft"
      add :language, :string, null: false
      add :generated_text, :text, null: false
      add :edited_text, :text
      add :linkedin_post_urn, :string
      add :published_at, :utc_datetime
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:linkedin_post_shares, [:post_id])
  end
end
