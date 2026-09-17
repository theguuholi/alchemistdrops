defmodule Alchemistdrops.Posts.Slug do
  @moduledoc false

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
