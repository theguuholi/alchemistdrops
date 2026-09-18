defmodule Alchemistdrops.Accounts.User do
  @moduledoc """
  Represents an account that can authenticate with Alchemistdrops.

  The schema owns the user's identity, password credentials, confirmation state,
  and authorization role. Its changesets protect credential invariants before
  account data reaches the `Alchemistdrops.Accounts` context.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @user_role_type ~w(user admin student)a

  @typedoc "The authorization role assigned to a user."
  @type role :: :user | :admin | :student

  @typedoc "Database identifier. Nil until the user is persisted."
  @type id :: Ecto.UUID.t() | nil

  @typedoc "Account email address. Nil before registration data is supplied."
  @type email :: String.t() | nil

  @typedoc "Transient clear-text password. Nil unless a password changeset is being built."
  @type password :: String.t() | nil

  @typedoc "Persisted password hash. Nil until password authentication is configured."
  @type hashed_password :: String.t() | nil

  @typedoc "Time at which the email was confirmed. Nil for an unconfirmed account."
  @type confirmed_at :: DateTime.t() | nil

  @typedoc "Most recent authentication time carried by the virtual field."
  @type authenticated_at :: DateTime.t() | nil

  @typedoc "Timestamp when the account was persisted. Nil before persistence."
  @type inserted_at :: DateTime.t() | nil

  @typedoc "Timestamp when the account was last updated. Nil before persistence."
  @type updated_at :: DateTime.t() | nil

  @typedoc "A persisted or newly constructed Alchemistdrops account."
  @type t :: %__MODULE__{
          id: id(),
          email: email(),
          password: password(),
          hashed_password: hashed_password(),
          confirmed_at: confirmed_at(),
          authenticated_at: authenticated_at(),
          role: role(),
          inserted_at: inserted_at(),
          updated_at: updated_at()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :role, Ecto.Enum, values: @user_role_type, null: false, default: :user

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.

  ## Examples

      iex> changeset = Alchemistdrops.Accounts.User.email_changeset(
      ...>   %Alchemistdrops.Accounts.User{},
      ...>   %{email: "new-user@example.com"}
      ...> )
      iex> changeset.valid?
      true

      iex> changeset = Alchemistdrops.Accounts.User.email_changeset(
      ...>   %Alchemistdrops.Accounts.User{},
      ...>   %{email: "preview@example.com"},
      ...>   validate_unique: false
      ...> )
      iex> changeset.changes.email
      "preview@example.com"
  """
  @spec email_changeset(t(), map()) :: Ecto.Changeset.t(t())
  @spec email_changeset(t(), map(), keyword()) :: Ecto.Changeset.t(t())
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :role])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Alchemistdrops.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

  ## Examples

      iex> changeset = Alchemistdrops.Accounts.User.password_changeset(
      ...>   %Alchemistdrops.Accounts.User{},
      ...>   %{password: "SecurePassword123!"}
      ...> )
      iex> is_binary(changeset.changes.hashed_password)
      true

      iex> changeset = Alchemistdrops.Accounts.User.password_changeset(
      ...>   %Alchemistdrops.Accounts.User{},
      ...>   %{password: "SecurePassword123!"},
      ...>   hash_password: false
      ...> )
      iex> changeset.changes.password
      "SecurePassword123!"
  """
  @spec password_changeset(t(), map()) :: Ecto.Changeset.t(t())
  @spec password_changeset(t(), map(), keyword()) :: Ecto.Changeset.t(t())
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/,
      message: "at least one digit or punctuation character"
    )
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.

  ## Examples

      iex> changeset = Alchemistdrops.Accounts.User.confirm_changeset(
      ...>   %Alchemistdrops.Accounts.User{}
      ...> )
      iex> %DateTime{} = changeset.changes.confirmed_at
  """
  @spec confirm_changeset(t()) :: Ecto.Changeset.t(t())
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.

  ## Examples

      iex> password = "SecurePassword123!"
      iex> user = %Alchemistdrops.Accounts.User{hashed_password: Bcrypt.hash_pwd_salt(password)}
      iex> Alchemistdrops.Accounts.User.valid_password?(user, password)
      true
      iex> Alchemistdrops.Accounts.User.valid_password?(nil, password)
      false
  """
  @spec valid_password?(t() | nil, String.t()) :: boolean()
  def valid_password?(%Alchemistdrops.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
