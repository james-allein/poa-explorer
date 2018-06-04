defmodule EthereumJSONRPC.Geth.StructuredLogs do
  @moduledoc """
  Structred logs returned by [`debug_traceTransaction`](https://github.com/ethereum/go-ethereum/wiki/Management-APIs#debug_tracetransaction),
  which is an extension to the Ethereum JSONRPC standard that is only supported by
  [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  alias EthereumJSONRPC.Geth.StructuredLog

  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &StructuredLog.elixir_to_params_list/1)
  end

  def to_elixir(structured_logs) when is_list(structured_logs) do
    Enum.map(structured_logs, &StructuredLog.to_elixir/1)
  end
end
