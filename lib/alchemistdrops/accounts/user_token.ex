defmodule Alchemistdrops.Accounts.UserToken do
  @moduledoc """
  Represents short-lived authentication and account-change credentials.

  Tokens make individual sessions revocable and keep email-delivered secrets
  hashed at rest. Query builders in this module centralize each token's context
  and expiry rules so callers cannot accidentally validate a token incorrectly.
  """

  use Ecto.Schema
  import Ecto.Query
  alias Alchemistdrops.Accounts.{User, UserToken}

  @hash_algorithm :sha256
  @rand_size 32

  # It is very important to keep the magic link token expiry short,
  # since someone with access to the email may take over the account.
  @magic_link_validity_in_minutes 15
  @change_email_validity_in_days 7
  @session_validity_in_days 14

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @typedoc "Authentication purpose attached to a stored token."
  @type context :: String.t()

  @typedoc "A stored session, magic-link, or email-change token."
  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          token: binary() | nil,
          context: context() | nil,
          sent_to: String.t() | nil,
          authenticated_at: DateTime.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :utc_datetime
    belongs_to :user, Alchemistdrops.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.

  ## Examples

      iex> user = %Alchemistdrops.Accounts.User{id: Ecto.UUID.generate()}
      iex> {token, stored_token} = Alchemistdrops.Accounts.UserToken.build_session_token(user)
      iex> {byte_size(token), stored_token.context, stored_token.user_id == user.id}
      {32, "session", true}
  """
  @spec build_session_token(User.t()) :: {binary(), t()}
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now(:second)
    {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any, along with the token's creation time.

  The token is valid if it matches the value in the database and it has
  not expired (after @session_validity_in_days).

  ## Examples

      iex> {:ok, query} = Alchemistdrops.Accounts.UserToken.verify_session_token_query("session-token")
      iex> match?(%Ecto.Query{}, query)
      true
  """
  @spec verify_session_token_query(binary()) :: {:ok, Ecto.Query.t()}
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  @doc """
  Builds a token and its hash to be delivered to the user's email.

  The non-hashed token is sent to the user email while the
  hashed part is stored in the database. The original token cannot be reconstructed,
  which means anyone with read-only access to the database cannot directly use
  the token in the application to gain access. Furthermore, if the user changes
  their email in the system, the tokens sent to the previous email are no longer
  valid.

  Users can easily adapt the existing code to provide other types of delivery methods,
  for example, by phone numbers.

  ## Examples

      iex> user = %Alchemistdrops.Accounts.User{id: Ecto.UUID.generate(), email: "person@example.com"}
      iex> {encoded, stored_token} = Alchemistdrops.Accounts.UserToken.build_email_token(user, "login")
      iex> {is_binary(encoded), stored_token.context, stored_token.sent_to}
      {true, "login", "person@example.com"}
  """
  @spec build_email_token(User.t(), context()) :: {String.t(), t()}
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  If found, the query returns a tuple of the form `{user, token}`.

  The given token is valid if it matches its hashed counterpart in the
  database. This function also checks if the token is being used within
  15 minutes. The context of a magic link token is always "login".

  ## Examples

      iex> Alchemistdrops.Accounts.UserToken.verify_magic_link_token_query("not-base64!")
      :error
  """
  @spec verify_magic_link_token_query(String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "login"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^@magic_link_validity_in_minutes, "minute"),
            where: token.sent_to == user.email,
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user_token found by the token, if any.

  This is used to validate requests to change the user
  email.
  The given token is valid if it matches its hashed counterpart in the
  database and if it has not expired (after @change_email_validity_in_days).
  The context must always start with "change:".

  ## Examples

      iex> Alchemistdrops.Accounts.UserToken.verify_change_email_token_query("not-base64!", "change:old@example.com")
      :error
  """
  @spec verify_change_email_token_query(String.t(), String.t()) :: {:ok, Ecto.Query.t()} | :error
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(@change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  defp by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end
end
