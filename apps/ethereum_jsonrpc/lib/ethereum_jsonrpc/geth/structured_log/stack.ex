defmodule EthereumJSONRPC.Geth.StructuredLog.Stack do
  def to_elixir(stack) when is_list(stack) do
    Enum.map(stack, &hexadecimal_digits_to_bytes/1)
  end

  defp hexadecimal_digits_to_bytes(hexadecimal_digits)
       when is_binary(hexadecimal_digits) and byte_size(hexadecimal_digits) == 64 do
    {:ok, bytes} = Base.decode16(hexadecimal_digits, case: :mixed)

    bytes
  end
end
