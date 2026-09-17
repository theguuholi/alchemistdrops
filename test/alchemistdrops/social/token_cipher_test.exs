defmodule Alchemistdrops.Social.TokenCipherTest do
  use ExUnit.Case, async: false

  alias Alchemistdrops.Social.TokenCipher

  test "encrypts and decrypts an access token" do
    assert {:ok, ciphertext} = TokenCipher.encrypt("linkedin-access-token-value")
    assert ciphertext != "linkedin-access-token-value"
    assert {:ok, "linkedin-access-token-value"} = TokenCipher.decrypt(ciphertext)
  end

  test "rejects a token encrypted with a different key" do
    assert {:ok, ciphertext} = TokenCipher.encrypt("secret-token")

    original_key = Application.get_env(:alchemistdrops, :linkedin_token_encryption_key)
    Application.put_env(:alchemistdrops, :linkedin_token_encryption_key, "different-key")

    on_exit(fn ->
      Application.put_env(:alchemistdrops, :linkedin_token_encryption_key, original_key)
    end)

    assert {:error, :invalid_token} = TokenCipher.decrypt(ciphertext)
  end

  test "returns an error when the encryption key is not configured" do
    original_key = Application.get_env(:alchemistdrops, :linkedin_token_encryption_key)
    Application.delete_env(:alchemistdrops, :linkedin_token_encryption_key)

    on_exit(fn ->
      Application.put_env(:alchemistdrops, :linkedin_token_encryption_key, original_key)
    end)

    assert {:error, :encryption_key_not_configured} = TokenCipher.encrypt("secret-token")
    assert {:error, :encryption_key_not_configured} = TokenCipher.decrypt("ciphertext")
  end
end
