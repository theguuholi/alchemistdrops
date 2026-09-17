defmodule Alchemistdrops.Social.FakeContentGenerator do
  @behaviour Alchemistdrops.Social.ContentGenerator

  @controller_key {__MODULE__, :controller}
  @result_message {__MODULE__, :result}
  @static_result_key {__MODULE__, :static_result}
  @static_controller_key {__MODULE__, :static_controller}

  def controlled_by(controller), do: Process.put(@controller_key, controller)
  def reply(result), do: send(self(), {@result_message, result})
  def reply(pid, ref, result), do: send(pid, {@result_message, ref, result})
  def set_static_result(result), do: :persistent_term.put(@static_result_key, result)

  def set_static_controller(controller),
    do: :persistent_term.put(@static_controller_key, controller)

  def reset_static do
    :persistent_term.erase(@static_result_key)
    :persistent_term.erase(@static_controller_key)
  end

  @impl true
  def generate(post, article_url) do
    case Process.get(@controller_key) do
      nil -> generate_with_static_result(post, article_url)
      controller -> generate_synchronized(controller, post, article_url)
    end
  end

  defp generate_with_static_result(post, article_url) do
    case :persistent_term.get(@static_result_key, nil) do
      nil ->
        generate_locally(post, article_url)

      result ->
        case :persistent_term.get(@static_controller_key, nil) do
          nil -> :ok
          controller -> send(controller, {__MODULE__, :called, post, article_url})
        end

        result
    end
  end

  defp generate_locally(post, article_url) do
    send(self(), {__MODULE__, :called, post, article_url})

    receive do
      {@result_message, result} -> result
    after
      100 -> {:error, :fake_not_configured}
    end
  end

  defp generate_synchronized(controller, post, article_url) do
    ref = make_ref()
    send(controller, {__MODULE__, :called, self(), ref, post, article_url})

    receive do
      {@result_message, ^ref, result} -> result
    after
      5_000 -> {:error, :fake_not_configured}
    end
  end
end

defmodule Alchemistdrops.Social.FakeLinkedInClient do
  @behaviour Alchemistdrops.Social.LinkedInClient

  @controller_key {__MODULE__, :controller}
  @result_message {__MODULE__, :publish_result}
  @static_result_key {__MODULE__, :static_result}
  @static_controller_key {__MODULE__, :static_controller}

  def controlled_by(controller), do: Process.put(@controller_key, controller)
  def reply(result), do: send(self(), {@result_message, result})
  def reply(pid, ref, result), do: send(pid, {@result_message, ref, result})
  def set_static_result(result), do: :persistent_term.put(@static_result_key, result)

  def set_static_controller(controller),
    do: :persistent_term.put(@static_controller_key, controller)

  def reset_static do
    :persistent_term.erase(@static_result_key)
    :persistent_term.erase(@static_controller_key)
  end

  @impl true
  def authorization_url(_state), do: {:error, :not_configured}

  @impl true
  def exchange_code(_code), do: {:error, :not_configured}

  @impl true
  def fetch_profile(_access_token), do: {:error, :not_configured}

  @impl true
  def publish(access_token, member_urn, text, article_url, title) do
    case Process.get(@controller_key) do
      nil ->
        publish_with_static_result(access_token, member_urn, text, article_url, title)

      controller ->
        publish_synchronized(controller, access_token, member_urn, text, article_url, title)
    end
  end

  defp publish_with_static_result(access_token, member_urn, text, article_url, title) do
    case :persistent_term.get(@static_result_key, nil) do
      nil ->
        publish_locally(access_token, member_urn, text, article_url, title)

      result ->
        case :persistent_term.get(@static_controller_key, nil) do
          nil ->
            :ok

          controller ->
            send(
              controller,
              {__MODULE__, :publish_called, access_token, member_urn, text, article_url, title}
            )
        end

        result
    end
  end

  defp publish_locally(access_token, member_urn, text, article_url, title) do
    send(
      self(),
      {__MODULE__, :publish_called, access_token, member_urn, text, article_url, title}
    )

    receive do
      {@result_message, result} -> result
    after
      100 -> {:error, :fake_not_configured}
    end
  end

  defp publish_synchronized(controller, access_token, member_urn, text, article_url, title) do
    ref = make_ref()

    send(
      controller,
      {__MODULE__, :publish_called, self(), ref, access_token, member_urn, text, article_url,
       title}
    )

    receive do
      {@result_message, ^ref, result} -> result
    after
      5_000 -> {:error, :fake_not_configured}
    end
  end
end
