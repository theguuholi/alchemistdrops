defmodule Alchemistdrops.Repo.Migrations.CreateEnrollments do
  use Ecto.Migration

  def change do
    create table(:enrollments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :course_id, references(:courses, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "active"
      add :enrolled_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:enrollments, [:user_id])
    create index(:enrollments, [:course_id])
    create index(:enrollments, [:status])
    create unique_index(:enrollments, [:user_id, :course_id])
  end
end
