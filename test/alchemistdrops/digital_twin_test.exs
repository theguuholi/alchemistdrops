defmodule Alchemistdrops.DigitalTwinTest do
  use ExUnit.Case, async: true

  alias Alchemistdrops.DigitalTwin

  doctest Alchemistdrops.DigitalTwin

  @profile %{
    name: "Gustavo",
    title: "Engineer",
    location: "Brazil",
    tagline: "Elixir",
    bio: ["Builds reliable software."],
    education: "Computer Science",
    honors: "Community contributor"
  }

  @career [
    %{
      role: "Engineer",
      company: "Acme",
      period: "2024–present",
      location: "Remote",
      highlights: ["Improved delivery"]
    }
  ]

  describe "chat/4" do
    test "given a successful OpenRouter response, when chat runs, then it returns trimmed content" do
      request_fun = fn url, opts ->
        assert url == "https://openrouter.ai/api/v1/chat/completions"
        assert get_in(opts, [:json, :messages, Access.at(0), :role]) == "system"

        assert List.keyfind(opts[:headers], "Authorization", 0) ==
                 {"Authorization", "Bearer secret"}

        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => " Answer "}}]}}}
      end

      assert DigitalTwin.chat(
               @profile,
               @career,
               [%{role: "user", content: "What was the impact?"}],
               api_key: "secret",
               extra_context: "Additional facts",
               request_fun: request_fun
             ) == {:ok, "Answer"}
    end

    test "given a non-success response, when chat runs, then it returns the provider error" do
      request_fun = fn _url, _opts -> {:ok, %{status: 429, body: %{"error" => "limited"}}} end

      assert {:error, message} =
               DigitalTwin.chat(@profile, @career, [],
                 api_key: "secret",
                 request_fun: request_fun
               )

      assert message == ~s(OpenRouter returned 429: %{"error" => "limited"})
    end

    test "given a transport failure, when chat runs, then it returns a network error" do
      request_fun = fn _url, _opts -> {:error, %Req.TransportError{reason: :timeout}} end

      assert DigitalTwin.chat(@profile, @career, [],
               api_key: "secret",
               request_fun: request_fun
             ) == {:error, "Network error: :timeout"}
    end
  end
end
