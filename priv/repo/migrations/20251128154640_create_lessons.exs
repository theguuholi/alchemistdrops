defmodule Alchemistdrops.Repo.Migrations.CreateLessons do
  use Ecto.Migration

  def change do
    create table(:lessons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :course_id, references(:courses, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :description, :text
      add :content, :text
      add :order, :integer, default: 0, null: false
      add :duration, :integer
      add :video_url, :text
      add :published, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:lessons, [:course_id])
    create index(:lessons, [:course_id, :order])
    create index(:lessons, [:published])
  end
end
