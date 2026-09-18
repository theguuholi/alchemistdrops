defmodule Alchemistdrops.Accounts do
  @moduledoc """
  Defines the public boundary for account identity and authentication.

  Callers use this context to register and find users, manage credentials and
  roles, issue or revoke authentication tokens, and deliver account emails.
  Keeping those operations here prevents web and background layers from
  bypassing account invariants or depending directly on persistence details.
  """

  import Ecto.Query, warn: false

  alias Alchemistdrops.Accounts.{User, UserNotifier, UserToken}
  alias Alchemistdrops.Repo

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> email = "lookup-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> Alchemistdrops.Accounts.get_user_by_email(email).id == user.id
      true
      iex> Alchemistdrops.Accounts.get_user_by_email("unknown@example.com")
      nil

  """
  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> email = "password-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:ok, {user, []}} = Alchemistdrops.Accounts.update_user_password(
      ...>   user,
      ...>   %{password: "SecurePassword123!"}
      ...> )
      iex> Alchemistdrops.Accounts.get_user_by_email_and_password(
      ...>   email,
      ...>   "SecurePassword123!"
      ...> ).id == user.id
      true
      iex> Alchemistdrops.Accounts.get_user_by_email_and_password(email, "invalid")
      nil

  """
  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> email = "get-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> Alchemistdrops.Accounts.get_user!(user.id).id == user.id
      true

  """
  @spec get_user!(Ecto.UUID.t()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> email = "register-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, %Alchemistdrops.Accounts.User{email: ^email}} =
      ...>   Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:error, changeset} = Alchemistdrops.Accounts.register_user(%{email: "invalid"})
      iex> changeset.valid?
      false

  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.

  ## Examples

      iex> user = %Alchemistdrops.Accounts.User{authenticated_at: DateTime.utc_now()}
      iex> Alchemistdrops.Accounts.sudo_mode?(user)
      true
      iex> Alchemistdrops.Accounts.sudo_mode?(%Alchemistdrops.Accounts.User{}, -10)
      false
  """
  @spec sudo_mode?(User.t()) :: boolean()
  @spec sudo_mode?(User.t(), integer()) :: boolean()
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `Alchemistdrops.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> user = %Alchemistdrops.Accounts.User{}
      iex> %Ecto.Changeset{} = Alchemistdrops.Accounts.change_user_email(user)
      iex> Alchemistdrops.Accounts.change_user_email(user, %{email: "person@example.com"}).valid?
      true
      iex> changeset = Alchemistdrops.Accounts.change_user_email(
      ...>   user,
      ...>   %{email: "preview@example.com"},
      ...>   validate_unique: false
      ...> )
      iex> Ecto.Changeset.get_change(changeset, :email)
      "preview@example.com"

  """
  @spec change_user_email(User.t()) :: Ecto.Changeset.t(User.t())
  @spec change_user_email(User.t(), map()) :: Ecto.Changeset.t(User.t())
  @spec change_user_email(User.t(), map(), keyword()) :: Ecto.Changeset.t(User.t())
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.

  ## Examples

      iex> email = "update-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> Alchemistdrops.Accounts.update_user_email(user, "invalid-token")
      {:error, :transaction_aborted}
  """
  @spec update_user_email(User.t(), String.t()) ::
          {:ok, User.t()} | {:error, :transaction_aborted}
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `Alchemistdrops.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> user = %Alchemistdrops.Accounts.User{}
      iex> %Ecto.Changeset{} = Alchemistdrops.Accounts.change_user_password(user)
      iex> Alchemistdrops.Accounts.change_user_password(
      ...>   user,
      ...>   %{password: "SecurePassword123!"}
      ...> ).valid?
      true
      iex> changeset = Alchemistdrops.Accounts.change_user_password(
      ...>   user,
      ...>   %{password: "SecurePassword123!"},
      ...>   hash_password: false
      ...> )
      iex> Ecto.Changeset.get_change(changeset, :password)
      "SecurePassword123!"

  """
  @spec change_user_password(User.t()) :: Ecto.Changeset.t(User.t())
  @spec change_user_password(User.t(), map()) :: Ecto.Changeset.t(User.t())
  @spec change_user_password(User.t(), map(), keyword()) :: Ecto.Changeset.t(User.t())
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> email = "change-password-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:ok, {%Alchemistdrops.Accounts.User{}, []}} =
      ...>   Alchemistdrops.Accounts.update_user_password(
      ...>     user,
      ...>     %{password: "SecurePassword123!"}
      ...>   )
      iex> {:error, changeset} =
      ...>   Alchemistdrops.Accounts.update_user_password(user, %{password: "too short"})
      iex> changeset.valid?
      false

  """
  @spec update_user_password(User.t(), map()) ::
          {:ok, {User.t(), [struct()]}} | {:error, Ecto.Changeset.t(User.t())}
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.

  ## Examples

      iex> email = "session-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> token = Alchemistdrops.Accounts.generate_user_session_token(user)
      iex> is_binary(token)
      true
  """
  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.

  ## Examples

      iex> email = "signed-session-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> token = Alchemistdrops.Accounts.generate_user_session_token(user)
      iex> {session_user, %DateTime{}} = Alchemistdrops.Accounts.get_user_by_session_token(token)
      iex> session_user.id == user.id
      true
  """
  @spec get_user_by_session_token(binary()) :: {User.t(), DateTime.t()} | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.

  ## Examples

      iex> email = "magic-lookup-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {token, user_token} =
      ...>   Alchemistdrops.Accounts.UserToken.build_email_token(user, "login")
      iex> {:ok, _user_token} = Alchemistdrops.Repo.insert(user_token)
      iex> Alchemistdrops.Accounts.get_user_by_magic_link_token(token).id == user.id
      true
  """
  @spec get_user_by_magic_link_token(String.t()) :: User.t() | nil
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.

  ## Examples

      iex> email = "magic-login-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {token, user_token} =
      ...>   Alchemistdrops.Accounts.UserToken.build_email_token(user, "login")
      iex> {:ok, _user_token} = Alchemistdrops.Repo.insert(user_token)
      iex> {:ok, {confirmed_user, [_expired_token]}} =
      ...>   Alchemistdrops.Accounts.login_user_by_magic_link(token)
      iex> confirmed_user.confirmed_at != nil
      true
  """
  @spec login_user_by_magic_link(String.t()) ::
          {:ok, {User.t(), [struct()]}} | {:error, :not_found}
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> email = "deliver-update-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:ok, delivered_email} =
      ...>   Alchemistdrops.Accounts.deliver_user_update_email_instructions(
      ...>     user,
      ...>     user.email,
      ...>     &"https://example.test/change-email/#{&1}"
      ...>   )
      iex> delivered_email.to
      [{"", email}]

  """
  @spec deliver_user_update_email_instructions(
          User.t(),
          String.t(),
          (String.t() -> String.t())
        ) :: {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.

  ## Examples

      iex> email = "deliver-login-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:ok, delivered_email} = Alchemistdrops.Accounts.deliver_login_instructions(
      ...>   user,
      ...>   &"https://example.test/login/\#{&1}"
      ...> )
      iex> delivered_email.to
      [{"", email}]
  """
  @spec deliver_login_instructions(User.t(), (String.t() -> String.t())) ::
          {:ok, Swoosh.Email.t()} | {:error, term()}
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.

  ## Examples

      iex> email = "delete-session-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> token = Alchemistdrops.Accounts.generate_user_session_token(user)
      iex> Alchemistdrops.Accounts.delete_user_session_token(token)
      :ok
      iex> Alchemistdrops.Accounts.get_user_by_session_token(token)
      nil
  """
  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  ## Admin functions

  @doc """
  Returns all users ordered by most recent first.

  ## Examples

      iex> email = "list-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> Enum.any?(Alchemistdrops.Accounts.list_users(), &(&1.id == user.id))
      true

  """
  @spec list_users() :: [User.t()]
  def list_users do
    User
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the total count of users.

  ## Examples

      iex> before_count = Alchemistdrops.Accounts.count_users()
      iex> email = "count-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, _user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> Alchemistdrops.Accounts.count_users() == before_count + 1
      true

  """
  @spec count_users() :: non_neg_integer()
  def count_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Updates a user's role.

  ## Examples

      iex> email = "role-#{System.unique_integer([:positive])}@example.com"
      iex> {:ok, user} = Alchemistdrops.Accounts.register_user(%{email: email})
      iex> {:ok, updated_user} = Alchemistdrops.Accounts.update_user_role(user, :admin)
      iex> updated_user.role
      :admin

  """
  @spec update_user_role(User.t(), :user | :admin) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t(User.t())}
  def update_user_role(%User{} = user, role) when role in [:user, :admin] do
    user
    |> Ecto.Changeset.change(role: role)
    |> Repo.update()
  end
end
