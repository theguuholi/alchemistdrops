defmodule Alchemistdrops.DigitalTwin do
  @moduledoc """
  Digital Twin: answers questions about Gustavo's career using OpenRouter.
  """
  @openrouter_url "https://openrouter.ai/api/v1/chat/completions"
  @model "arcee-ai/trinity-large-preview:free"

  @doc """
  Sends the conversation (with system context) to OpenRouter and returns the assistant reply.

  Returns `{:ok, content}` or `{:error, reason}`.
  """
  def chat(profile, career, messages) do
    api_key = Application.get_env(:alchemistdrops, :openrouter_api_key)

    if is_nil(api_key) or api_key == "" do
      {:error, :api_key_not_configured}
    else
      system_content = build_system_prompt(profile, career)

      openrouter_messages =
        [%{role: "system", content: system_content} | to_openrouter_messages(messages)]

      body = %{
        model: @model,
        messages: openrouter_messages,
        max_tokens: 1024,
        temperature: 0.7
      }

      case Req.post(@openrouter_url,
             json: body,
             headers: [
               {"Authorization", "Bearer #{api_key}"},
               {"Content-Type", "application/json"}
             ],
             receive_timeout: 60_000
           ) do
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
          {:ok, String.trim(content)}

        {:ok, %{status: status, body: body}} ->
          {:error, "OpenRouter returned #{status}: #{inspect(body)}"}

        {:error, %Req.TransportError{reason: reason}} ->
          {:error, "Network error: #{inspect(reason)}"}
      end
    end
  end

  defp build_system_prompt(profile, career) do
    career_text =
      Enum.map_join(career, "\n", fn entry ->
        "- #{entry.role} at #{entry.company} (#{entry.period}, #{entry.location}). " <>
          "Highlights: #{Enum.join(entry.highlights, " ")}
"
      end)

    """
    You are a "Digital Twin" of Gustavo Oliveira —
    a friendly, professional voice that answers questions about his career and experience based only on the following facts. Be concise and accurate. If asked something not covered below, say you don't have that information and suggest the user reach out to Gustavo directly.

    ## Profile
    - Name: #{profile.name}
    - Title: #{profile.title}
    - Location: #{profile.location}
    - Tagline: #{profile.tagline}
    - Bio: #{Enum.join(profile.bio, " ")}
    - Education: #{profile.education}
    - Honors: #{profile.honors}

    ## Career (most recent first)
    #{career_text}
    """
    |> String.replace("\n\n\n", "\n\n")
    |> String.trim()
  end

  defp to_openrouter_messages(messages) do
    Enum.map(messages, fn %{role: role, content: content} ->
      %{role: role, content: content}
    end)
  end
end
