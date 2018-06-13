defmodule Explorer.Indexer.AddressExtractionTest do
  use Explorer.DataCase, async: true

  alias Explorer.Indexer.AddressExtraction

  doctest AddressExtraction

  describe "extract_addresses/1" do
    test "blocks must have `miner_hash` or it is an ArgumentError" do
      assert_raise ArgumentError,
                   """
                   No extract format matches params.

                   Extract Format(s):
                   1. [%{from: :number, to: :fetched_balance_block_number}, %{from: :miner_hash, to: :hash}]}

                   Params:
                   %{number: 34}
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       blocks: [
                         %{
                           number: 34
                         }
                       ]
                     })
                   end
    end

    test "blocks must have `number` or it is an ArgumentError" do
      assert_raise ArgumentError,
                   """
                   No extract format matches params.

                   Extract Format(s):
                   1. [%{from: :number, to: :fetched_balance_block_number}, %{from: :miner_hash, to: :hash}]}

                   Params:
                   %{miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"}
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       blocks: [
                         %{
                           miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
                         }
                       ]
                     })
                   end
    end

    test "internal_transactions must have `block_number` or it is an ArgumentError" do
      assert_raise ArgumentError,
                   """
                   No extract format matches params.

                   Extract Format(s):
                   1. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :from_address_hash, to: :hash}]}
                   2. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :to_address_hash, to: :hash}]}
                   3. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :created_contract_address_hash, to: :hash}, %{from: :created_contract_code, to: :contract_code}]}

                   Params:
                   %{from_address_hash: "0x0000000000000000000000000000000000000001"}
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       internal_transactions: [
                         %{
                           from_address_hash: "0x0000000000000000000000000000000000000001"
                         }
                       ]
                     })
                   end

      assert_raise ArgumentError,
                   """
                   No extract format matches params.

                   Extract Format(s):
                   1. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :from_address_hash, to: :hash}]}
                   2. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :to_address_hash, to: :hash}]}
                   3. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :created_contract_address_hash, to: :hash}, %{from: :created_contract_code, to: :contract_code}]}

                   Params:
                   %{to_address_hash: "0x0000000000000000000000000000000000000002"}
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       internal_transactions: [
                         %{
                           to_address_hash: "0x0000000000000000000000000000000000000002"
                         }
                       ]
                     })
                   end

      assert_raise ArgumentError,
                   """
                   No extract format matches params.

                   Extract Format(s):
                   1. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :from_address_hash, to: :hash}]}
                   2. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :to_address_hash, to: :hash}]}
                   3. [%{from: :block_number, to: :fetched_balance_block_number}, %{from: :created_contract_address_hash, to: :hash}, %{from: :created_contract_code, to: :contract_code}]}

                   Params:
                   %{created_contract_address_hash: "0x0000000000000000000000000000000000000003", created_contract_code: "0x"}
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       internal_transactions: [
                         %{
                           created_contract_address_hash: "0x0000000000000000000000000000000000000003",
                           created_contract_code: "0x"
                         }
                       ]
                     })
                   end
    end

    test "differing contract code causes an ArgumentError" do
      assert_raise ArgumentError,
                   """
                   contract_code differs:

                   0x1

                   0x2
                   """,
                   fn ->
                     Explorer.Indexer.AddressExtraction.extract_addresses(%{
                       internal_transactions: [
                         %{
                           block_number: 1,
                           created_contract_code: "0x1",
                           created_contract_address_hash: "0x0000000000000000000000000000000000000001"
                         },
                         %{
                           block_number: 2,
                           created_contract_code: "0x2",
                           created_contract_address_hash: "0x0000000000000000000000000000000000000001"
                         }
                       ]
                     })
                   end
    end

    test "returns empty list with empty data" do
      empty_blockchain_data = %{
        blocks: [],
        transactions: [],
        internal_transactions: [],
        logs: []
      }

      addresses = AddressExtraction.extract_addresses(empty_blockchain_data)

      assert Enum.empty?(addresses)
    end

    test "entities not defined in @entity_to_extract_format_list cause an error" do
      assert_raise KeyError, fn ->
        AddressExtraction.extract_addresses(%{
          unkown_entity: [%{hash: "0x8bf38d4764929064f2d4d3a56520a76ab3df415b"}]
        })
      end
    end

    test "returns an empty list when there isn't a recognized entity" do
      addresses = AddressExtraction.extract_addresses(%{})

      assert Enum.empty?(addresses)
    end
  end
end
