defmodule EthereumJSONRPC.Geth.StructuredLog.Error do
  def to_elixir(error) when is_map(error) do
    Enum.into(error, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir(entry) do
    IO.inspect(entry, label: "#{__MODULE__} entry")
    raise "BOOM"
  end
end
