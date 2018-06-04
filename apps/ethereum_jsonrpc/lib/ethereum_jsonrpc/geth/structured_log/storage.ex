defmodule EthereumJSONRPC.Geth.StructuredLog.Storage do
  def to_elixir(storage) when is_map(storage) do
    Enum.into(storage, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir(entry) do
    IO.inspect(entry, label: "#{__MODULE__} entry")
    raise "BOOM"
  end
end
