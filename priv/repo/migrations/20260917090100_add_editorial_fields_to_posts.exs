defmodule Alchemistdrops.Repo.Migrations.AddEditorialFieldsToPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime
      add :summary, :string
      add :seo_title, :string
      add :seo_description, :string
      add :cover_image_url, :string
      add :cover_image_alt, :string
      add :language, :string, null: false, default: "en"
      add :category_id, references(:post_categories, type: :binary_id)

      add :related_course_id,
          references(:courses, type: :binary_id, on_delete: :nilify_all)
    end

    execute("UPDATE posts SET status = 'published', published_at = inserted_at")
    execute("UPDATE posts SET views = 0 WHERE views IS NULL")

    alter table(:posts) do
      modify :views, :integer, null: false, default: 0
    end

    create index(:posts, [:status, :published_at])
    create index(:posts, [:category_id])
    create index(:posts, [:related_course_id])
  end

  def down do
    drop index(:posts, [:related_course_id])
    drop index(:posts, [:category_id])
    drop index(:posts, [:status, :published_at])

    alter table(:posts) do
      modify :views, :integer, null: true, default: nil
      remove :related_course_id
      remove :category_id
      remove :language
      remove :cover_image_alt
      remove :cover_image_url
      remove :seo_description
      remove :seo_title
      remove :summary
      remove :published_at
      remove :status
    end
  end
end
