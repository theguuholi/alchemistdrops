defmodule Alchemistdrops.Repo.Migrations.AddRoles do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE user_role AS ENUM ('user', 'admin', 'student')", ""

    alter table(:users) do
      add :role, :user_role, null: false, default: "user"
    end
  end
end
