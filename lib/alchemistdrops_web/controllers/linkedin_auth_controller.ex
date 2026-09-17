defmodule AlchemistdropsWeb.LinkedInAuthController do
  @moduledoc """
  Handles the administrator-only OAuth handshake for the personal LinkedIn connection.
  """

  use AlchemistdropsWeb, :controller

  alias Alchemistdrops.Social

  @state_bytes 32

  @doc "Starts the LinkedIn authorization flow for a persisted post."
  def connect(conn, %{"post_id" => post_id}) do
    state = @state_bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    return_to = ~p"/admin/posts/#{post_id}/edit"

    authorization_result =
      if encryption_key_configured?() do
        linkedin_client().authorization_url(state)
      else
        {:error, :not_configured}
      end

    case authorization_result do
      {:ok, authorization_url} ->
        conn
        |> put_session(:linkedin_oauth_state, state)
        |> put_session(:linkedin_oauth_return_to, return_to)
        |> redirect(external: authorization_url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "LinkedIn integration is not configured.")
        |> redirect(to: return_to)
    end
  end

  @doc "Completes the LinkedIn authorization flow and stores the personal connection."
  def callback(conn, params) do
    stored_state = get_session(conn, :linkedin_oauth_state)
    return_to = get_session(conn, :linkedin_oauth_return_to) || ~p"/admin/posts"

    conn =
      conn
      |> delete_session(:linkedin_oauth_state)
      |> delete_session(:linkedin_oauth_return_to)

    if valid_state?(stored_state, params["state"]) do
      complete_callback(conn, params, return_to)
    else
      conn
      |> put_flash(:error, "LinkedIn authorization could not be verified. Please try again.")
      |> redirect(to: return_to)
    end
  end

  defp complete_callback(conn, %{"error" => _error}, return_to) do
    conn
    |> put_flash(:error, "LinkedIn authorization was not completed.")
    |> redirect(to: return_to)
  end

  defp complete_callback(conn, %{"code" => code}, return_to) do
    client = linkedin_client()

    with {:ok, %{access_token: access_token, expires_in: expires_in}} <-
           client.exchange_code(code),
         {:ok, %{member_urn: member_urn}} <- client.fetch_profile(access_token),
         {:ok, _connection} <-
           Social.store_connection(%{
             access_token: access_token,
             expires_in: expires_in,
             member_urn: member_urn
           }) do
      conn
      |> put_flash(:info, "LinkedIn profile connected.")
      |> redirect(to: return_to)
    else
      {:error, _reason} ->
        conn
        |> put_flash(:error, "LinkedIn could not connect. Please try again.")
        |> redirect(to: return_to)
    end
  end

  defp complete_callback(conn, _params, return_to) do
    conn
    |> put_flash(:error, "LinkedIn could not connect. Please try again.")
    |> redirect(to: return_to)
  end

  defp valid_state?(stored_state, returned_state)
       when is_binary(stored_state) and is_binary(returned_state) and
              byte_size(stored_state) == byte_size(returned_state) do
    Plug.Crypto.secure_compare(stored_state, returned_state)
  end

  defp valid_state?(_stored_state, _returned_state), do: false

  defp linkedin_client do
    Application.fetch_env!(:alchemistdrops, :linkedin_client)
  end

  defp encryption_key_configured? do
    case Application.get_env(:alchemistdrops, :linkedin_token_encryption_key) do
      key when is_binary(key) and byte_size(key) > 0 -> true
      _other -> false
    end
  end
end
