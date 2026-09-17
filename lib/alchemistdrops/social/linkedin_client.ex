defmodule Alchemistdrops.Social.LinkedInClient do
  @moduledoc """
  Defines the LinkedIn OAuth, profile, and personal-posting boundary.
  """

  @type error_reason ::
          :not_configured
          | :invalid_response
          | {:http_error, pos_integer()}
          | {:request_error, :http_protocol | :unexpected}
          | {:transport_error, term()}

  @callback authorization_url(state :: String.t()) ::
              {:ok, String.t()} | {:error, error_reason()}

  @callback exchange_code(code :: String.t()) ::
              {:ok, %{access_token: String.t(), expires_in: non_neg_integer()}}
              | {:error, error_reason()}

  @callback fetch_profile(access_token :: String.t()) ::
              {:ok, %{member_urn: String.t()}} | {:error, error_reason()}

  @callback publish(
              access_token :: String.t(),
              member_urn :: String.t(),
              text :: String.t(),
              article_url :: String.t(),
              title :: String.t()
            ) :: {:ok, %{post_urn: String.t()}} | {:error, error_reason()}
end
