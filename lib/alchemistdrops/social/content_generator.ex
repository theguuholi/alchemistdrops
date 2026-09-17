defmodule Alchemistdrops.Social.ContentGenerator do
  @callback generate(Alchemistdrops.Posts.Post.t(), String.t()) ::
              {:ok, %{language: String.t(), text: String.t()}} | {:error, term()}
end
