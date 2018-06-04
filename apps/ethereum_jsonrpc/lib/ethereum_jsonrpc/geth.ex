defmodule EthereumJSONRPC.Geth do
  @moduledoc """
  Ethereum JSONRPC methods that are only supported by [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  require Logger

  import EthereumJSONRPC, only: [config: 1, json_rpc: 2]

  alias EthereumJSONRPC.Geth.StructuredLogs

  @behaviour EthereumJSONRPC.Variant

  @doc """
  Fetches the `t:Explorer.Chain.InternalTransaction.changeset/2` params from the Geth URL.

      iex> EthereumJSONRPC.Geth.fetch_internal_transactions([
      ...>   "0x2ec382949ba0b22443aa4cb38267b1fb5e68e188109ac11f7a82f67571a0adf3"
      ...> ])
      :foo

  """
  def fetch_internal_transactions(transaction_params) when is_list(transaction_params) do
    {requests, id_to_transaction_hashes} =
      transaction_params
      |> Stream.with_index()
      |> Enum.reduce({[], %{}}, fn {transaction_hash, id}, {acc_requests, acc_id_to_transaction_hash} ->
        requests = [request(id, transaction_hash) | acc_requests]
        id_to_transaction_hash = Map.put(acc_id_to_transaction_hash, id, transaction_hash)
        {requests, id_to_transaction_hash}
      end)

    with {:ok, responses} <- json_rpc(requests, config(:url)) do
      internal_transactions_params =
        responses
        |> responses_to_structured_logs(id_to_transaction_hashes)
        |> StructuredLogs.to_elixir()
        |> StructuredLogs.elixir_to_params()

      {:ok, internal_transactions_params}
    end
  end

  defp request(id, transaction_hash) when is_integer(id) and is_binary(transaction_hash) do
    %{
      "id" => id,
      "jsonrpc" => "2.0",
      "method" => "debug_traceTransaction",
      "params" => [transaction_hash, %{}]
    }
  end

  defp response_to_structured_logs(%{"id" => id} = response, id_to_transaction_hash)
       when is_map(id_to_transaction_hash) do
    transaction_hash = Map.fetch!(id_to_transaction_hash, id)

    case response do
      %{"result" => result} -> result_to_structured_logs(result, transaction_hash)
      %{"error" => error} -> error_to_structured_logs(error, transaction_hash)
    end
  end

  defp result_to_structured_logs(%{"structLogs" => structured_logs}, transaction_hash) do
    structured_logs
    |> Stream.with_index()
    |> Enum.map(fn {structured_log, index} ->
      Map.merge(structured_log, %{"index" => index, "transactionHash" => transaction_hash})
    end)
  end

  defp error_to_structured_logs(%{"code" => code, "message" => message}, transaction_hash) do
    Logger.error(fn ->
      [
        "Error getting debug_traceTransaction for transaction hash (",
        transaction_hash,
        "):\n  code: ",
        to_string(code),
        "\n  message: ",
        message
      ]
    end)

    []
  end

  defp responses_to_structured_logs(responses, id_to_transaction_hash)
       when is_list(responses) and is_map(id_to_transaction_hash) do
    Enum.flat_map(responses, &response_to_structured_logs(&1, id_to_transaction_hash))
  end
end
