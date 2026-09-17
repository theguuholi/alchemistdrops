defmodule Alchemistdrops.Social.TokenCipher do
  alias Plug.Crypto.MessageEncryptor

  @aad "linkedin-access-token"

  def encrypt(token) when is_binary(token) do
    with {:ok, key} <- encryption_key() do
      {:ok, MessageEncryptor.encrypt(token, @aad, key, @aad)}
    end
  end

  def decrypt(ciphertext) when is_binary(ciphertext) do
    with {:ok, key} <- encryption_key() do
      case MessageEncryptor.decrypt(ciphertext, @aad, key, @aad) do
        {:ok, token} -> {:ok, token}
        :error -> {:error, :invalid_token}
      end
    end
  rescue
    _ -> {:error, :invalid_token}
  end

  defp encryption_key do
    case Application.get_env(:alchemistdrops, :linkedin_token_encryption_key) do
      key when is_binary(key) and byte_size(key) > 0 ->
        {:ok, :crypto.hash(:sha256, key)}

      _ ->
        {:error, :encryption_key_not_configured}
    end
  end
end
