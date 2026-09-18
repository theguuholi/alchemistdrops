defmodule Alchemistdrops.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Alchemistdrops.Accounts` context.
  """

  import Ecto.Query

  alias Alchemistdrops.Accounts
  alias Alchemistdrops.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "HelloWorld123!@Alchemistdrops"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    # Convert keyword list to map if needed
    attrs = if is_list(attrs), do: Map.new(attrs), else: attrs

    # Extract special attributes before creating user
    role = Map.get(attrs, :role, :user)
    # Convert string role to atom if needed
    role = if is_binary(role), do: String.to_existing_atom(role), else: role

    confirmed_at = Map.get(attrs, :confirmed_at, :default)
    attrs = Map.drop(attrs, [:role, :confirmed_at])

    user = unconfirmed_user_fixture(attrs)

    # Handle confirmation
    user =
      case confirmed_at do
        nil ->
          # Explicitly unconfirmed
          user

        :default ->
          # Default: confirm via magic link
          token =
            extract_user_token(fn url ->
              Accounts.deliver_login_instructions(user, url)
            end)

          {:ok, {confirmed_user, _expired_tokens}} =
            Accounts.login_user_by_magic_link(token)

          confirmed_user

        datetime ->
          # Custom confirmed_at timestamp
          user
          |> Ecto.Changeset.change(confirmed_at: datetime)
          |> Alchemistdrops.Repo.update!()
      end

    # Set role if different from default
    if role == :user do
      user
    else
      user
      |> Ecto.Changeset.change(role: role)
      |> Alchemistdrops.Repo.update!()
    end
  end

  def admin_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :role, :admin)
    user_fixture(attrs)
  end

  def student_fixture(attrs \\ %{}) do
    attrs = Map.put(attrs, :role, :student)
    user_fixture(attrs)
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Alchemistdrops.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    Alchemistdrops.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Alchemistdrops.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
