defmodule Explorer.SmartContract.Reader do
  @moduledoc """
  Reads Smart Contract functions from the blockchain.
  """

  alias Explorer.Chain.Hash

  @doc """
  Queries a contract function on the blockchain and returns the call result.

  ## Examples

     Explorer.SmartContract.Reader.query_contract(
       "0x62eb5ed811d02e774a53066646e2281ce337a3d9",
       "multiply(uint256)",
       [10]
     )
     # => 1024
  """
  def query_contract(address_hash, function_name, args \\ []) do
    data = setup_call_data(function_name, args)

    address_hash
    |> EthereumJSONRPC.execute_contract_function(data)
    |> decode_call_result()
  end

  defp setup_call_data(function_name, args) do
    function_hash = Hash.binary_to_keccak(function_name)
    encoded_arguments = encode_arguments(args)

    "0x" <> function_hash <> encoded_arguments
  end

  defp encode_arguments([]), do: ""

  defp encode_arguments(args) do
    args
    |> Enum.map(&encode_argument/1)
    |> Enum.join()
  end

  defp encode_argument(int) when is_integer(int) do
    int
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end

  defp encode_argument(str) when is_binary(str) do
    str
    |> Base.encode16(case: :lower)
    |> String.pad_leading(64, "0")
  end

  # TODO: consider the cases in which the result is not an integer.
  defp decode_call_result({:ok, "0x" <> result}) do
    Integer.parse(result, 16)
  end
end
