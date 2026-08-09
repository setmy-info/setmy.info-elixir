defmodule SetmyInfo.Commons.Collection.Operations do
  @moduledoc """
  Collection operations. Direct port of `info.setmy.collection.operations`
  (clj-commons); python-commons inlines the same behaviour with
  `itertools.product` instead of giving it its own module.
  """

  @doc """
  Concatenates a list of lists into one list. Clojure's `apply-concat-many`
  is variadic; Elixir has no variadic functions, so this takes the lists as
  one argument - the only shape difference from the Clojure original.
  """
  @spec apply_concat_many([list()]) :: list()
  def apply_concat_many(lists), do: Enum.concat(lists)

  @doc """
  Cartesian product of two lists, combined pairwise by `product_function`.
  The function can be anything two-arity - `*` (the default, matching the
  Clojure original), `+`, string concatenation, ...
  """
  @spec product(list(), list(), (term(), term() -> term())) :: list()
  def product(list_a, list_b, product_function \\ &Kernel.*/2) do
    for x <- list_a, y <- list_b, do: product_function.(x, y)
  end

  @doc """
  Cartesian product of two lists as `{left, right}` tuples - the Elixir
  equivalent of the Clojure original's two-element vectors.
  """
  @spec product_as_pairs(list(), list()) :: [{term(), term()}]
  def product_as_pairs(dimension_a, dimension_b) do
    for x <- dimension_a, y <- dimension_b, do: {x, y}
  end
end
