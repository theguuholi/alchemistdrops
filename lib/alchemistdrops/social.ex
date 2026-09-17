defmodule Alchemistdrops.Social do
  @moduledoc """
  Coordinates the personal LinkedIn connection, draft generation, and publication workflow.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Alchemistdrops.Posts.Post
  alias Alchemistdrops.Repo
  alias Alchemistdrops.Social.LinkedInConnection
  alias Alchemistdrops.Social.LinkedInPostShare
  alias Alchemistdrops.Social.TokenCipher

  @connection_id "personal"
  @connection_error_message "LinkedIn connection is missing or expired."
  @publication_error_message "LinkedIn publication failed. Please try again."

  @doc "Returns the singleton personal LinkedIn connection when one has been stored."
  @spec get_connection() :: LinkedInConnection.t() | nil
  def get_connection, do: Repo.get(LinkedInConnection, @connection_id)

  @doc "Reports whether the stored personal connection has an unexpired access token."
  @spec connected?() :: boolean()
  def connected?, do: connected?(get_connection())

  @doc "Encrypts and stores the authorized personal LinkedIn connection."
  @spec store_connection(%{
          access_token: String.t(),
          expires_in: non_neg_integer(),
          member_urn: String.t()
        }) :: {:ok, LinkedInConnection.t()} | {:error, term()}
  def store_connection(%{
        access_token: access_token,
        expires_in: expires_in,
        member_urn: member_urn
      })
      when is_binary(access_token) and is_integer(expires_in) and expires_in >= 0 and
             is_binary(member_urn) do
    with {:ok, ciphertext} <- TokenCipher.encrypt(access_token) do
      expires_at = DateTime.add(DateTime.utc_now(:second), expires_in, :second)

      %LinkedInConnection{}
      |> LinkedInConnection.changeset(%{
        access_token_ciphertext: ciphertext,
        expires_at: expires_at,
        member_urn: member_urn
      })
      |> Repo.insert(
        conflict_target: :id,
        on_conflict:
          {:replace, [:member_urn, :access_token_ciphertext, :expires_at, :updated_at]},
        returning: true
      )
    end
  end

  @doc "Returns the LinkedIn share associated with an article."
  def get_share(%Post{id: post_id}), do: Repo.get_by(LinkedInPostShare, post_id: post_id)

  @doc "Generates and persists a draft without replacing a valid draft on generation failure."
  def generate_share(%Post{} = post, article_url) when is_binary(article_url) do
    share = get_share(post)

    with :ok <- generation_allowed(share),
         {:ok, %{language: language, text: text}}
         when is_binary(language) and is_binary(text) <-
           content_generator().generate(post, article_url),
         changeset <- generation_changeset(post.id, language, text),
         :ok <- validate_generation(changeset) do
      persist_generation(changeset, post)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} when reason in [:publish_in_progress, :already_published] ->
        {:error, reason}

      external_error ->
        log_external_failure(:generation, external_error)
        {:error, :generation_failed}
    end
  end

  @doc "Updates the editable text while a share is a draft or failed."
  def update_share_text(%LinkedInPostShare{} = share, text)
      when is_binary(text) or is_nil(text) do
    changeset = LinkedInPostShare.edit_changeset(share, %{edited_text: text})

    if changeset.valid? do
      updates = [
        edited_text: Ecto.Changeset.get_field(changeset, :edited_text),
        updated_at: now()
      ]

      query =
        from social_share in LinkedInPostShare,
          where: social_share.id == ^share.id and social_share.status in [:draft, :failed]

      case Repo.update_all(query, set: updates) do
        {1, nil} -> {:ok, Repo.get!(LinkedInPostShare, share.id)}
        {0, nil} -> {:error, :share_not_editable}
      end
    else
      {:error, changeset}
    end
  end

  @doc "Claims and synchronously publishes a draft or failed share exactly once."
  def publish_share(%Post{} = post, article_url) when is_binary(article_url) do
    claim_query =
      from social_share in LinkedInPostShare,
        where: social_share.post_id == ^post.id and social_share.status in [:draft, :failed]

    case Repo.update_all(claim_query,
           set: [status: :publishing, error_message: nil, updated_at: now()]
         ) do
      {1, nil} -> publish_claimed_share(get_share(post), post, article_url)
      {0, nil} -> publication_claim_error(get_share(post))
    end
  end

  defp connected?(nil), do: false

  defp connected?(%LinkedInConnection{} = connection),
    do:
      match?(
        {:ok, _access_token, _member_urn, _ciphertext},
        decrypt_current_connection(connection)
      )

  defp generation_allowed(nil), do: :ok

  defp generation_allowed(%LinkedInPostShare{status: status}) when status in [:draft, :failed],
    do: :ok

  defp generation_allowed(%LinkedInPostShare{status: :publishing}),
    do: {:error, :publish_in_progress}

  defp generation_allowed(%LinkedInPostShare{status: :published}),
    do: {:error, :already_published}

  defp generation_changeset(post_id, language, text) do
    %LinkedInPostShare{post_id: post_id}
    |> LinkedInPostShare.generation_changeset(%{language: language, generated_text: text})
  end

  defp validate_generation(%Ecto.Changeset{valid?: true}), do: :ok
  defp validate_generation(%Ecto.Changeset{} = changeset), do: {:error, changeset}

  defp persist_generation(changeset, post) do
    conflict_query =
      from social_share in LinkedInPostShare,
        update: [
          set: [
            status: fragment("EXCLUDED.status"),
            language: fragment("EXCLUDED.language"),
            generated_text: fragment("EXCLUDED.generated_text"),
            edited_text: nil,
            linkedin_post_urn: nil,
            published_at: nil,
            error_message: nil,
            updated_at: fragment("EXCLUDED.updated_at")
          ]
        ],
        where: social_share.status in [:draft, :failed]

    case Repo.insert(changeset,
           conflict_target: :post_id,
           on_conflict: conflict_query,
           returning: true,
           stale_error_field: :status
         ) do
      {:ok, share} -> {:ok, share}
      {:error, stale_changeset} -> generation_persist_error(get_share(post), stale_changeset)
    end
  end

  defp generation_persist_error(%LinkedInPostShare{status: :publishing}, _changeset),
    do: {:error, :publish_in_progress}

  defp generation_persist_error(%LinkedInPostShare{status: :published}, _changeset),
    do: {:error, :already_published}

  defp generation_persist_error(_share, changeset), do: {:error, changeset}

  defp publish_claimed_share(%LinkedInPostShare{} = share, post, article_url) do
    case current_credentials() do
      {:ok, access_token, member_urn, ciphertext} ->
        publish_with_credentials(
          share,
          post,
          article_url,
          access_token,
          member_urn,
          ciphertext
        )

      {:error, :linkedin_connection_required} ->
        fail_publication(share, :linkedin_connection_required, @connection_error_message)
    end
  end

  defp publish_with_credentials(
         share,
         post,
         article_url,
         access_token,
         member_urn,
         ciphertext
       ) do
    case linkedin_client().publish(
           access_token,
           member_urn,
           share.edited_text || share.generated_text,
           article_url,
           post.title
         ) do
      {:ok, %{post_urn: post_urn}} when is_binary(post_urn) and byte_size(post_urn) > 0 ->
        transition_publication(share,
          status: :published,
          linkedin_post_urn: post_urn,
          published_at: now(),
          error_message: nil
        )

      {:error, {:http_error, 401}} = error ->
        log_external_failure(:publication, error)
        invalidate_connection(ciphertext)
        fail_publication(share, :linkedin_connection_required, @connection_error_message)

      external_error ->
        log_external_failure(:publication, external_error)
        fail_publication(share, :linkedin_publish_failed, @publication_error_message)
    end
  end

  defp current_credentials do
    case get_connection() do
      %LinkedInConnection{} = connection -> decrypt_current_connection(connection)
      nil -> {:error, :linkedin_connection_required}
    end
  end

  defp decrypt_current_connection(%LinkedInConnection{} = connection) do
    if DateTime.compare(connection.expires_at, DateTime.utc_now(:second)) == :gt do
      case TokenCipher.decrypt(connection.access_token_ciphertext) do
        {:ok, access_token} ->
          {:ok, access_token, connection.member_urn, connection.access_token_ciphertext}

        {:error, _reason} ->
          {:error, :linkedin_connection_required}
      end
    else
      {:error, :linkedin_connection_required}
    end
  end

  defp invalidate_connection(ciphertext) do
    from(connection in LinkedInConnection,
      where:
        connection.id == ^@connection_id and
          connection.access_token_ciphertext == ^ciphertext
    )
    |> Repo.delete_all()

    :ok
  end

  defp log_external_failure(operation, external_error) do
    Logger.warning(
      "#{external_failure_label(operation)} failed (#{safe_error_details(external_error)})"
    )
  end

  defp external_failure_label(:generation), do: "LinkedIn content generation"
  defp external_failure_label(:publication), do: "LinkedIn publication"

  defp safe_error_details({:error, reason}), do: safe_error_details(reason)

  defp safe_error_details({:http_error, status}) when is_integer(status),
    do: "category=http_error status=#{status}"

  defp safe_error_details({:transport_error, _reason}), do: "category=transport_error"
  defp safe_error_details({:request_error, _reason}), do: "category=request_error"
  defp safe_error_details(:invalid_response), do: "category=invalid_response"
  defp safe_error_details(:api_key_not_configured), do: "category=configuration_error"
  defp safe_error_details(:not_configured), do: "category=configuration_error"
  defp safe_error_details(_reason), do: "category=external_error"

  defp fail_publication(share, reason, message) do
    case transition_publication(share, status: :failed, error_message: message) do
      {:ok, _failed_share} -> {:error, reason}
      {:error, :publication_state_changed} = error -> error
    end
  end

  defp transition_publication(share, updates) do
    query =
      from social_share in LinkedInPostShare,
        where: social_share.id == ^share.id and social_share.status == :publishing

    case Repo.update_all(query, set: Keyword.put(updates, :updated_at, now())) do
      {1, nil} -> {:ok, Repo.get!(LinkedInPostShare, share.id)}
      {0, nil} -> {:error, :publication_state_changed}
    end
  end

  defp publication_claim_error(nil), do: {:error, :share_not_found}

  defp publication_claim_error(%LinkedInPostShare{status: :publishing}),
    do: {:error, :publish_in_progress}

  defp publication_claim_error(%LinkedInPostShare{status: :published}),
    do: {:error, :already_published}

  defp publication_claim_error(%LinkedInPostShare{}), do: {:error, :publish_not_available}

  defp content_generator,
    do: Application.fetch_env!(:alchemistdrops, :linkedin_content_generator)

  defp linkedin_client, do: Application.fetch_env!(:alchemistdrops, :linkedin_client)

  defp now, do: DateTime.utc_now(:second)
end
