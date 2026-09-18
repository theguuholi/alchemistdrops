defmodule Alchemistdrops.Posts.Slug do
  @moduledoc """
  Normalizes post titles into stable, URL-safe slug candidates.
  """

  @doc """
  Converts a value to a lowercase ASCII slug and falls back to `"post"`.

  ## Examples

      iex> Alchemistdrops.Posts.Slug.from("Introdução ao Elixir")
      "introducao-ao-elixir"

      iex> Alchemistdrops.Posts.Slug.from(nil)
      "post"
  """
  @spec from(term()) :: String.t()
  def from(value) when is_binary(value) do
    slug =
      value
      |> String.normalize(:nfd)
      |> String.replace(~r/[\p{Mn}]/u, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    if slug == "", do: "post", else: slug
  end

  def from(_value), do: "post"
end
