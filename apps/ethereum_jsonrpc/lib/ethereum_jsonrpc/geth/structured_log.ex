defmodule EthereumJSONRPC.Geth.StructuredLog do
  @moduledoc """
  Structred log returned by [`debug_traceTransaction`](https://github.com/ethereum/go-ethereum/wiki/Management-APIs#debug_tracetransaction),
  which is an extension to the Ethereum JSONRPC standard that is only supported by
  [Geth](https://github.com/ethereum/go-ethereum/wiki/geth).
  """

  alias EthereumJSONRPC.Geth.StructuredLog.{Error, Memory, Stack, Storage}

  # Ethereum Yellow Paper (https://ethereum.github.io/yellowpaper/paper.pdf) and
  # https://ethereum.stackexchange.com/a/120 lists operations

  # EVM words are 256-bits wide, PUSH<N> is for bytes and 32 bytes = 256 bits
  @push_ops Enum.map(1..32, &"PUSH#{&1}")

  # Duplicates Nth item on stack and puts it on the top of the stack
  @dup_ops Enum.map(1..16, &"DUP#{&1}")

  # Swaps the 1st and Nth item on the stack
  @swap_ops Enum.map(1..16, &"SWAP#{&1}")

  # There are at most 4 log topics
  @log_ops Enum.map(0..4, &"LOG#{&1}")

  # Ordered by the opcode's numeric value, so it can be compared with Ethereum Yellow Paper section.  All known opcodes
  # are listed, so that if new opcodes are added, the code will fail and we'll have to make an affirmative choice of
  # whether the op needs to be stored as an internal transaction or ignored.
  @ops ~w(
    STOP
    ADD
    MUL
    SUB
    DIV
    SDIV
    MOD
    SMOD
    ADDMOD
    MULMOD
    EXP
    SIGNEXTEND
    LT
    GT
    SLT
    SGT
    EQ
    ISZERO
    AND
    OR
    XOR
    NOT
    BYTE
    SHA3
    ADDRESS
    BALANCE
    ORIGIN
    CALLER
    CALLVALUE
    CALLDATALOAD
    CALLDATASIZE
    CALLDATACOPY
    CODESIZE
    CODECOPY
    GASPRICE
    EXTCODESIZE
    EXTCODECOPY
    RETURNDATASIZE
    RETURNDATACOPY
    BLOCKHASH
    COINBASE
    TIMESTAMP
    NUMBER
    DIFFICULTY
    GASLIMIT
    POP
    MLOAD
    MSTORE
    MSTORE8
    SLOAD
    SSTORE
    JUMP
    JUMPI
    PC
    MSIZE
    GAS
    JUMPDEST
  ) ++ @push_ops ++ @dup_ops ++ @swap_ops ++ @log_ops ++ ~w(
    CREATE
    CALL
    CALLCODE
    RETURN
    DELEGATECALL
    STATICCALL
    REVERT
    INVALID
    SELFDESTRUCT
  )

  @doc """
  Returns either a singleton list if the `elixir` represents an `op` that is recorded as an
  `Explorer.Chain.InternalTransaction` or an empty list otherwise.
  """

  # https://github.com/ethereum/go-ethereum/blob/master/eth/tracers/internal/tracers/call_tracer.js#L68-L96
  def elixir_to_params_list(
        %{"op" => "CALL", "index" => index, "gas" => gas, "gasCost" => gas_used, "transactionHash" => transaction_hash} =
          elixir
      ) do
    input = transput(elixir, 2)
    output = transput(elixir, 4)

    [
      %{
        transaction_hash: transaction_hash,
        index: index,
        type: :call,
        call_type: :call,
        gas: gas,
        gas_used: gas_used,
        input: input,
        output: output
      }
    ]
  end

  @ignored_ops @ops -- ~w(CALL CALLCODE CREATE DELEGATECALL REVERT STATICCALL)

  # known ops that are not converted to internal transactions
  def elixir_to_params_list(%{"op" => op}) when op in @ignored_ops, do: []

  def to_elixir(%{"index" => _, "transactionHash" => _} = structured_log) do
    Enum.into(structured_log, %{}, &entry_to_elixir/1)
  end

  def to_elixir(_) do
    raise ArgumentError, ~S|Caller must `Map.put/2` `"index"` and `"transactionHash"` in trace|
  end

  defp entry_to_elixir({key, _} = entry) when key in ~w(depth gas gasCost index op pc transactionHash), do: entry

  defp entry_to_elixir({"error" = key, error}) do
    {key, Error.to_elixir(error)}
  end

  defp entry_to_elixir({"memory" = key, memory}) do
    {key, Memory.to_elixir(memory)}
  end

  defp entry_to_elixir({"stack" = key, stack}) do
    {key, Stack.to_elixir(stack)}
  end

  defp entry_to_elixir({"storage" = key, storage}) do
    {key, Storage.to_elixir(storage)}
  end

  defp transput(%{"memory" => memory, "stack" => stack}, offset) do
    [<<memoryStart::big-integer-size(256)>>, <<memoryLength::big-integer-size(256)>>] = Enum.slice(stack, offset, 2)

    memory
    |> Enum.slice(memoryStart, memoryLength)
    |> Enum.join()
  end
end
