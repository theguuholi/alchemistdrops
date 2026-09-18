defmodule Alchemistdrops.Accounts.UserTokenTest do
  use Alchemistdrops.DataCase, async: true

  alias Alchemistdrops.Accounts.UserToken

  doctest Alchemistdrops.Accounts.UserToken

  describe "token builders" do
    test "given a user, when a session token is built, then the raw token is not hashed" do
      user = %Alchemistdrops.Accounts.User{id: Ecto.UUID.generate()}

      {raw_token, stored_token} = UserToken.build_session_token(user)

      assert byte_size(raw_token) == 32
      assert stored_token.token == raw_token
      assert stored_token.context == "session"
      assert stored_token.user_id == user.id
    end

    test "given a user, when an email token is built, then only its hash is stored" do
      user = %Alchemistdrops.Accounts.User{
        id: Ecto.UUID.generate(),
        email: "person@example.com"
      }

      {encoded_token, stored_token} = UserToken.build_email_token(user, "login")

      assert {:ok, raw_token} = Base.url_decode64(encoded_token, padding: false)
      refute stored_token.token == raw_token
      assert stored_token.token == :crypto.hash(:sha256, raw_token)
      assert stored_token.sent_to == user.email
    end
  end

  describe "token verification queries" do
    test "given malformed encoded tokens, when email verification is built, then it rejects them" do
      assert UserToken.verify_magic_link_token_query("not-base64!") == :error

      assert UserToken.verify_change_email_token_query(
               "not-base64!",
               "change:old@example.com"
             ) == :error
    end
  end
end
