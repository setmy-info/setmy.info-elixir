defmodule SetmyInfo.Commons.Collection.OperationsTest do
    @moduledoc """
    Unit tier (ADR-0031). clj-commons ships `info.setmy.collection.operations`
    without its own test namespace - covered here directly, since
    `String.Operations.combined_list/3` builds on it.
    """

    use ExUnit.Case, async: true

    alias SetmyInfo.Commons.Collection.Operations

    test "apply_concat_many/1 flattens one level, in order" do
        assert Operations.apply_concat_many([["a"], [], ["b", "c"]]) == ["a", "b", "c"]
        assert Operations.apply_concat_many([]) == []
    end

    test "product/3 multiplies by default and accepts any two-arity function" do
        assert Operations.product([1, 2], [3, 4]) == [3, 4, 6, 8]
        assert Operations.product([1, 2], [3, 4], &Kernel.+/2) == [4, 5, 5, 6]
        assert Operations.product(["a", "b"], ["x"], &Kernel.<>/2) == ["ax", "bx"]
    end

    test "product_as_pairs/2 yields every combination as a tuple" do
        assert Operations.product_as_pairs(["A", "B"], ["X", "Y"]) ==
                          [{"A", "X"}, {"A", "Y"}, {"B", "X"}, {"B", "Y"}]

        assert Operations.product_as_pairs(["A"], []) == []
    end
end
