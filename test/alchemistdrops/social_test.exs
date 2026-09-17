defmodule Alchemistdrops.SocialTest do
  use Alchemistdrops.DataCase, async: false
  use Mimic

  import ExUnit.CaptureLog
  import Alchemistdrops.PostsFixtures

  alias Alchemistdrops.Social
  alias Alchemistdrops.Social.{LinkedInPostShare, OpenRouterContentGenerator}
  alias Alchemistdrops.Social.{ReqLinkedInClient, TokenCipher}

  test "get_connection/0 returns nil when the personal connection is absent" do
    assert Social.get_connection() == nil
  end

  test "store_connection/1 encrypts and persists the singleton with a calculated expiry" do
    before_store = DateTime.utc_now(:second)

    assert {:ok, connection} =
             Social.store_connection(%{
               access_token: "linkedin-access-token",
               expires_in: 3_600,
               member_urn: "urn:li:person:abc123"
             })

    after_store = DateTime.utc_now(:second)

    assert connection.id == "personal"
    assert connection.member_urn == "urn:li:person:abc123"
    refute connection.access_token_ciphertext == "linkedin-access-token"

    assert {:ok, "linkedin-access-token"} =
             TokenCipher.decrypt(connection.access_token_ciphertext)

    assert DateTime.compare(connection.expires_at, DateTime.add(before_store, 3_600, :second)) in [
             :eq,
             :gt
           ]

    assert DateTime.compare(connection.expires_at, DateTime.add(after_store, 3_600, :second)) in [
             :eq,
             :lt
           ]

    assert Social.get_connection().id == connection.id
  end

  test "store_connection/1 replaces the existing personal connection" do
    assert {:ok, first} =
             Social.store_connection(%{
               access_token: "first-token",
               expires_in: 60,
               member_urn: "urn:li:person:first"
             })

    assert {:ok, replacement} =
             Social.store_connection(%{
               access_token: "replacement-token",
               expires_in: 7_200,
               member_urn: "urn:li:person:replacement"
             })

    assert replacement.id == first.id
    assert replacement.member_urn == "urn:li:person:replacement"
    assert {:ok, "replacement-token"} = TokenCipher.decrypt(replacement.access_token_ciphertext)
    assert Social.get_connection().member_urn == "urn:li:person:replacement"
  end

  test "connected?/0 is false without a stored connection" do
    refute Social.connected?()
  end

  test "connected?/0 is true while the stored access token is unexpired" do
    assert {:ok, _connection} =
             Social.store_connection(%{
               access_token: "valid-token",
               expires_in: 60,
               member_urn: "urn:li:person:abc123"
             })

    assert Social.connected?()
  end

  test "connected?/0 is false once the stored access token expires" do
    assert {:ok, _connection} =
             Social.store_connection(%{
               access_token: "expired-token",
               expires_in: 0,
               member_urn: "urn:li:person:abc123"
             })

    refute Social.connected?()
  end

  test "connected?/0 is false when the stored access token cannot be decrypted" do
    assert {:ok, connection} =
             Social.store_connection(%{
               access_token: "valid-token",
               expires_in: 60,
               member_urn: "urn:li:person:abc123"
             })

    connection
    |> change(access_token_ciphertext: "not-a-valid-ciphertext")
    |> Repo.update!()

    refute Social.connected?()
  end

  describe "LinkedIn post shares" do
    test "get_share/1 returns nil when the article has no share" do
      assert Social.get_share(post_fixture()) == nil
    end

    test "generate_share/2 creates one draft and regeneration replaces its preview" do
      post = post_fixture(%{title: "Shipping small changes", body: "A practical article."})
      article_url = "https://example.com/blog/#{post.id}"

      expect_generation(
        {:ok, %{language: "en", text: "First preview. Read more: #{article_url}"}}
      )

      assert {:ok, first_share} = Social.generate_share(post, article_url)
      assert first_share.status == :draft
      assert first_share.language == "en"
      assert first_share.generated_text == "First preview. Read more: #{article_url}"

      assert {:ok, edited_share} = Social.update_share_text(first_share, "My edited preview")
      assert edited_share.edited_text == "My edited preview"

      expect_generation(
        {:ok, %{language: "pt-BR", text: "Segundo preview. Leia: #{article_url}"}}
      )

      assert {:ok, regenerated_share} = Social.generate_share(post, article_url)
      assert regenerated_share.id == first_share.id
      assert regenerated_share.status == :draft
      assert regenerated_share.language == "pt-BR"
      assert regenerated_share.generated_text == "Segundo preview. Leia: #{article_url}"
      assert regenerated_share.edited_text == nil
      assert regenerated_share.error_message == nil
      assert Repo.aggregate(LinkedInPostShare, :count) == 1
    end

    test "generation failure preserves the last valid draft and sanitizes the result" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      generated_text = "A valid preview. Read more: #{article_url}"

      expect_generation({:ok, %{language: "en", text: generated_text}})
      assert {:ok, share} = Social.generate_share(post, article_url)
      assert {:ok, _share} = Social.update_share_text(share, "Keep this edited text")

      expect_generation({:error, %{body: "raw provider response with secret access-token"}})

      log =
        capture_log(fn ->
          assert {:error, :generation_failed} = Social.generate_share(post, article_url)
        end)

      persisted_share = Social.get_share(post)
      assert persisted_share.id == share.id
      assert persisted_share.status == :draft
      assert persisted_share.generated_text == generated_text
      assert persisted_share.edited_text == "Keep this edited text"
      refute inspect(persisted_share) =~ "raw provider response"
      refute inspect(persisted_share) =~ "secret access-token"
      assert log =~ "LinkedIn content generation failed (category=external_error)"
      refute log =~ "raw provider response"
      refute log =~ "secret access-token"
    end

    test "invalid generated content does not replace a valid draft" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"

      expect_generation({:ok, %{language: "en", text: "Valid preview"}})
      assert {:ok, share} = Social.generate_share(post, article_url)

      expect_generation({:ok, %{language: "en", text: String.duplicate("x", 3_001)}})

      assert {:error, %Ecto.Changeset{}} = Social.generate_share(post, article_url)
      assert Social.get_share(post).generated_text == share.generated_text
    end

    test "concurrent first generations upsert one editable share and both return it" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      parent = self()
      expect_controlled_generation(parent, 2)

      first_task = generation_task(post, article_url)
      second_task = generation_task(post, article_url)

      assert_receive {:generation_called, first_pid, first_ref, ^post, ^article_url}
      assert_receive {:generation_called, second_pid, second_ref, ^post, ^article_url}

      reply_to_call(
        first_pid,
        first_ref,
        {:ok, %{language: "en", text: "First concurrent preview"}}
      )

      reply_to_call(
        second_pid,
        second_ref,
        {:ok, %{language: "pt-BR", text: "Segundo preview concorrente"}}
      )

      assert {:ok, first_share} = Task.await(first_task)
      assert {:ok, second_share} = Task.await(second_task)
      assert first_share.id == second_share.id
      assert Repo.aggregate(LinkedInPostShare, :count) == 1
      assert Social.get_share(post).status == :draft
    end

    test "update_share_text/2 persists edits only for draft or failed shares" do
      post = post_fixture()
      share = generate_share(post)

      assert {:ok, draft_share} = Social.update_share_text(share, "Edited draft")
      assert draft_share.edited_text == "Edited draft"

      failed_share = set_share_status(draft_share, :failed)
      assert {:ok, failed_share} = Social.update_share_text(failed_share, "Edited retry")
      assert failed_share.edited_text == "Edited retry"

      publishing_share = set_share_status(failed_share, :publishing)

      assert {:error, :share_not_editable} =
               Social.update_share_text(publishing_share, "Too late")

      assert Social.get_share(post).edited_text == "Edited retry"

      published_share = set_share_status(publishing_share, :published)
      assert {:error, :share_not_editable} = Social.update_share_text(published_share, "Too late")
      assert Social.get_share(post).edited_text == "Edited retry"
    end

    test "publish_share/2 atomically claims a draft and publishes the edited text" do
      post = post_fixture(%{title: "A title sent to LinkedIn"})
      article_url = "https://example.com/blog/#{post.id}"
      share = generate_share(post, article_url)
      assert {:ok, _share} = Social.update_share_text(share, "The administrator's final text")
      store_valid_connection()

      expect(ReqLinkedInClient, :publish, fn access_token,
                                             member_urn,
                                             text,
                                             received_url,
                                             title ->
        assert access_token == "valid-access-token"
        assert member_urn == "urn:li:person:publisher"
        assert text == "The administrator's final text"
        assert received_url == article_url
        assert title == "A title sent to LinkedIn"
        {:ok, %{post_urn: "urn:li:share:published123"}}
      end)

      before_publish = DateTime.utc_now(:second)

      assert {:ok, published_share} = Social.publish_share(post, article_url)

      after_publish = DateTime.utc_now(:second)
      assert published_share.status == :published
      assert published_share.linkedin_post_urn == "urn:li:share:published123"
      assert published_share.error_message == nil

      assert DateTime.compare(published_share.published_at, before_publish) in [:eq, :gt]
      assert DateTime.compare(published_share.published_at, after_publish) in [:eq, :lt]

      assert Social.get_share(post).status == :published
    end

    test "publish failure stores a safe error, retains text, and permits retry" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      share = generate_share(post, article_url)
      assert {:ok, _share} = Social.update_share_text(share, "Retain this edited text")
      store_valid_connection()

      expect_publication(
        {:error, {:transport_error, %{body: "raw LinkedIn body with bearer secret-access-token"}}}
      )

      log =
        capture_log(fn ->
          assert {:error, :linkedin_publish_failed} = Social.publish_share(post, article_url)
        end)

      failed_share = Social.get_share(post)
      assert failed_share.status == :failed
      assert failed_share.generated_text == share.generated_text
      assert failed_share.edited_text == "Retain this edited text"
      assert failed_share.error_message == "LinkedIn publication failed. Please try again."
      refute inspect(failed_share) =~ "raw LinkedIn body"
      refute inspect(failed_share) =~ "secret-access-token"
      assert log =~ "LinkedIn publication failed (category=transport_error)"
      refute log =~ "raw LinkedIn body"
      refute log =~ "secret-access-token"

      expect_publication({:ok, %{post_urn: "urn:li:share:retry123"}})
      assert {:ok, retried_share} = Social.publish_share(post, article_url)
      assert retried_share.status == :published
      assert retried_share.linkedin_post_urn == "urn:li:share:retry123"
      assert retried_share.error_message == nil
      assert retried_share.edited_text == "Retain this edited text"
    end

    test "a LinkedIn 401 invalidates the connection and stores a safe connection error" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      share = generate_share(post, article_url)
      store_valid_connection()

      expect_publication({:error, {:http_error, 401}})

      log =
        capture_log(fn ->
          assert {:error, :linkedin_connection_required} =
                   Social.publish_share(post, article_url)
        end)

      assert Social.get_connection() == nil
      failed_share = Social.get_share(post)
      assert failed_share.status == :failed
      assert failed_share.generated_text == share.generated_text
      assert failed_share.error_message == "LinkedIn connection is missing or expired."
      assert log =~ "LinkedIn publication failed (category=http_error status=401)"
      refute log =~ "valid-access-token"
    end

    test "publish_share/2 rejects publishing and published shares without calling the client" do
      post = post_fixture()
      share = generate_share(post)
      store_valid_connection()
      reject(ReqLinkedInClient, :publish, 5)

      publishing_share = set_share_status(share, :publishing)
      assert {:error, :publish_in_progress} = Social.publish_share(post, "https://example.com")

      set_share_status(publishing_share, :published)
      assert {:error, :already_published} = Social.publish_share(post, "https://example.com")
    end

    test "competing publication claims invoke the LinkedIn client exactly once" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      generate_share(post, article_url)
      store_valid_connection()
      parent = self()
      expect_controlled_publication(parent)

      first_task = publication_task(post, article_url)

      assert_receive {:publication_called, first_pid, first_ref, "valid-access-token",
                      "urn:li:person:publisher", _text, ^article_url, _title}

      second_task = publication_task(post, article_url)
      assert {:error, :publish_in_progress} = Task.await(second_task)

      reply_to_call(
        first_pid,
        first_ref,
        {:ok, %{post_urn: "urn:li:share:single-publication"}}
      )

      assert {:ok, published_share} = Task.await(first_task)
      assert published_share.status == :published
      assert published_share.linkedin_post_urn == "urn:li:share:single-publication"
    end

    test "generation started before publication cannot reopen or alter the published share" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      original_share = generate_share(post, article_url)
      store_valid_connection()
      parent = self()
      expect_controlled_generation(parent)
      expect_controlled_publication(parent)

      generation_task = generation_task(post, article_url)

      assert_receive {:generation_called, generation_pid, generation_ref, ^post, ^article_url}

      publication_task = publication_task(post, article_url)

      assert_receive {:publication_called, publication_pid, publication_ref, "valid-access-token",
                      "urn:li:person:publisher", _text, ^article_url, _title}

      reply_to_call(
        publication_pid,
        publication_ref,
        {:ok, %{post_urn: "urn:li:share:won-race"}}
      )

      assert {:ok, published_share} = Task.await(publication_task)
      assert published_share.status == :published

      reply_to_call(
        generation_pid,
        generation_ref,
        {:ok, %{language: "en", text: "Stale generation must not persist"}}
      )

      assert {:error, :already_published} = Task.await(generation_task)

      persisted_share = Social.get_share(post)
      assert persisted_share.status == :published
      assert persisted_share.generated_text == original_share.generated_text
      assert persisted_share.linkedin_post_urn == "urn:li:share:won-race"
      assert persisted_share.published_at == published_share.published_at
    end

    test "publication success does not overwrite a share that is no longer publishing" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      generate_share(post, article_url)
      store_valid_connection()
      parent = self()
      expect_controlled_publication(parent)
      task = publication_task(post, article_url)

      assert_receive {:publication_called, publication_pid, publication_ref, _, _, _, _, _}

      Social.get_share(post) |> set_share_status(:failed)

      reply_to_call(
        publication_pid,
        publication_ref,
        {:ok, %{post_urn: "urn:li:share:stale-success"}}
      )

      assert {:error, :publication_state_changed} = Task.await(task)
      persisted_share = Social.get_share(post)
      assert persisted_share.status == :failed
      assert persisted_share.linkedin_post_urn == nil
      assert persisted_share.published_at == nil
    end

    test "publication failure does not overwrite a share that is no longer publishing" do
      post = post_fixture()
      article_url = "https://example.com/blog/#{post.id}"
      generate_share(post, article_url)
      store_valid_connection()
      parent = self()
      expect_controlled_publication(parent)
      task = publication_task(post, article_url)

      assert_receive {:publication_called, publication_pid, publication_ref, _, _, _, _, _}

      published_at = DateTime.utc_now(:second)

      Social.get_share(post)
      |> Ecto.Changeset.change(
        status: :published,
        linkedin_post_urn: "urn:li:share:other-writer",
        published_at: published_at
      )
      |> Repo.update!()

      capture_log(fn ->
        reply_to_call(
          publication_pid,
          publication_ref,
          {:error, {:request_error, :unexpected}}
        )

        assert {:error, :publication_state_changed} = Task.await(task)
      end)

      persisted_share = Social.get_share(post)
      assert persisted_share.status == :published
      assert persisted_share.linkedin_post_urn == "urn:li:share:other-writer"
      assert persisted_share.published_at == published_at
      assert persisted_share.error_message == nil
    end

    test "publish_share/2 requires a current unexpired connection after claiming the share" do
      post = post_fixture()
      share = generate_share(post)
      reject(ReqLinkedInClient, :publish, 5)

      assert {:ok, _connection} =
               Social.store_connection(%{
                 access_token: "expired-secret-token",
                 expires_in: 0,
                 member_urn: "urn:li:person:expired"
               })

      assert {:error, :linkedin_connection_required} =
               Social.publish_share(post, "https://example.com")

      failed_share = Social.get_share(post)
      assert failed_share.status == :failed
      assert failed_share.generated_text == share.generated_text
      assert failed_share.error_message == "LinkedIn connection is missing or expired."
      refute inspect(failed_share) =~ "expired-secret-token"
    end
  end

  defp generate_share(post, article_url \\ "https://example.com/blog/article") do
    expect_generation(
      {:ok, %{language: "en", text: "Generated preview. Read more: #{article_url}"}}
    )

    assert {:ok, share} = Social.generate_share(post, article_url)
    share
  end

  defp expect_generation(result) do
    expect(OpenRouterContentGenerator, :generate, fn _post, _article_url -> result end)
  end

  defp expect_publication(result) do
    expect(ReqLinkedInClient, :publish, fn _access_token,
                                           _member_urn,
                                           _text,
                                           _article_url,
                                           _title ->
      result
    end)
  end

  defp expect_controlled_generation(parent, call_count \\ 1) do
    expect(OpenRouterContentGenerator, :generate, call_count, fn post, article_url ->
      await_controlled_reply(parent, :generation_called, [post, article_url])
    end)
  end

  defp expect_controlled_publication(parent) do
    expect(ReqLinkedInClient, :publish, fn access_token, member_urn, text, article_url, title ->
      await_controlled_reply(
        parent,
        :publication_called,
        [access_token, member_urn, text, article_url, title]
      )
    end)
  end

  defp await_controlled_reply(parent, message, arguments) do
    ref = make_ref()
    send(parent, List.to_tuple([message, self(), ref | arguments]))

    receive do
      {:controlled_reply, ^ref, result} -> result
    after
      5_000 -> {:error, {:request_error, :unexpected}}
    end
  end

  defp reply_to_call(pid, ref, result), do: send(pid, {:controlled_reply, ref, result})

  defp generation_task(post, article_url),
    do: Task.async(fn -> Social.generate_share(post, article_url) end)

  defp publication_task(post, article_url),
    do: Task.async(fn -> Social.publish_share(post, article_url) end)

  defp set_share_status(share, status) do
    share
    |> Ecto.Changeset.change(status: status)
    |> Repo.update!()
  end

  defp store_valid_connection do
    assert {:ok, connection} =
             Social.store_connection(%{
               access_token: "valid-access-token",
               expires_in: 3_600,
               member_urn: "urn:li:person:publisher"
             })

    connection
  end
end
