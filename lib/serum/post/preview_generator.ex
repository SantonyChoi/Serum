defmodule Serum.Post.PreviewGenerator do
  @moduledoc false

  _moduledocp = "Generates a preview text from a blog post."

  @more_tag "<!--more-->"

  @spec generate_preview(binary(), term(), binary() | nil) :: binary()
  def generate_preview(html, length, excerpt \\ nil)

  # If excerpt is provided, use it
  def generate_preview(_html, _length, excerpt) when is_binary(excerpt) and excerpt != "", do: excerpt

  # If more tag exists, use content before it
  def generate_preview(html, length, _excerpt) do
    case String.split(html, @more_tag, parts: 2) do
      [before, _after] -> before |> clean_html()
      [_single] -> generate_preview_from_html(html, length)
    end
  end

  defp generate_preview_from_html(_html, l) when is_integer(l) and l <= 0, do: ""
  defp generate_preview_from_html(_html, {_, l}) when is_integer(l) and l <= 0, do: ""

  defp generate_preview_from_html(html, l) when is_integer(l) do
    html |> Floki.parse_document!() |> do_generate_preview({:chars, l})
  end

  defp generate_preview_from_html(html, {_, l} = lspec) when is_integer(l) do
    html |> Floki.parse_document!() |> do_generate_preview(lspec)
  end

  defp generate_preview_from_html(_html, _), do: ""

  @spec do_generate_preview(Floki.html_tree(), {term(), non_neg_integer()}) :: binary()
  defp do_generate_preview(html, lspec)

  defp do_generate_preview(html_tree, {:chars, l}) do
    html_tree
    |> Floki.text(sep: " ")
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, l)
    |> append_ellipsis()
  end

  defp do_generate_preview(html_tree, {:words, l}) do
    html_tree
    |> Floki.text(sep: " ")
    |> String.split(~r/\s/, trim: true)
    |> Enum.take(l)
    |> Enum.join(" ")
    |> append_ellipsis()
  end

  defp do_generate_preview(html_tree, {:paragraphs, l}) do
    html_tree
    |> Floki.find("p")
    |> Enum.take(l)
    |> Enum.map_join(" ", &(&1 |> Floki.text() |> String.trim()))
    |> append_ellipsis()
  end

  defp do_generate_preview(_html_tree, _), do: ""

  defp clean_html(html) do
    html
    |> Floki.parse_document!()
    |> Floki.text(sep: " ")
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp append_ellipsis(""), do: ""
  defp append_ellipsis(text), do: text <> "\u2026"
end
