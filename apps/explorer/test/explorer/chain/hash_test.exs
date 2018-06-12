defmodule Explorer.Chain.HashTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.Hash

  doctest Explorer.Chain.Hash

  describe "binary_to_keccack/2" do
    test "returns the first 4 bytes of the encrypted string by default" do
      string = "double(int256)"
      encrypted_string = "6ffa1caa"
      assert Hash.binary_to_keccak(string) == encrypted_string
    end

    test "returns the desired number of bytes of the encrypted string" do
      string = "double(int256)"
      encrypted_string = "6ffa1caacdbca40c71e3787a33872771f2864c218eaf6f1b2f862d9323ba1640"
      bytes_number = 32
      assert Hash.binary_to_keccak(string, bytes_number) == encrypted_string
    end
  end
end
