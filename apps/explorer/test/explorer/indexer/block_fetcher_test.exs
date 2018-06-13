defmodule Explorer.Indexer.BlockFetcherTest do
  # `async: false` due to use of named GenServer
  use Explorer.DataCase, async: false

  import ExUnit.CaptureLog

  alias Explorer.Chain.{Address, Block, Hash, InternalTransaction, Log, Transaction}
  alias Explorer.Indexer

  alias Explorer.Indexer.{
    AddressBalanceFetcher,
    AddressBalanceFetcherCase,
    BlockFetcher,
    InternalTransactionFetcher,
    InternalTransactionFetcherCase,
    Sequence
  }

  @tag capture_log: true

  # First block with all schemas to import
  # 37 is determined using the following query:
  # SELECT MIN(blocks.number) FROM
  # (SELECT blocks.number
  #  FROM internal_transactions
  #  INNER JOIN transactions
  #  ON transactions.hash = internal_transactions.transaction_hash
  #  INNER JOIN blocks
  #  ON blocks.hash = transactions.block_hash
  #  INTERSECT
  #  SELECT blocks.number
  #  FROM logs
  #  INNER JOIN transactions
  #  ON transactions.hash = logs.transaction_hash
  #  INNER JOIN blocks
  #  ON blocks.hash = transactions.block_hash) as blocks
  @first_full_block_number 37

  describe "start_link/1" do
    test "starts fetching blocks from latest and goes down" do
      {:ok, latest_block_number} = EthereumJSONRPC.fetch_block_number_by_tag("latest")

      default_blocks_batch_size = BlockFetcher.default_blocks_batch_size()

      assert latest_block_number > default_blocks_batch_size

      assert Repo.aggregate(Block, :count, :hash) == 0

      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      start_supervised!(BlockFetcher)

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^latest_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= 1

      previous_batch_block_number = latest_block_number - default_blocks_batch_size

      wait_for_results(fn ->
        Repo.one!(from(block in Block, where: block.number == ^previous_batch_block_number))
      end)

      assert Repo.aggregate(Block, :count, :hash) >= default_blocks_batch_size
    end
  end

  describe "handle_info(:debug_count, state)" do
    setup :state

    setup do
      block = insert(:block)

      Enum.map(0..2, fn _ ->
        transaction =
          :transaction
          |> insert()
          |> with_block(block)

        insert(:log, transaction_hash: transaction.hash)
        insert(:internal_transaction, transaction_hash: transaction.hash, index: 0)
      end)

      :ok
    end

    @tag :capture_log
    @heading "persisted counts"
    test "without debug_logs", %{state: state} do
      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()

      refute capture_log_at_level(:debug, fn ->
               Indexer.disable_debug_logs()
               BlockFetcher.handle_info(:debug_count, state)
             end) =~ @heading
    end

    @tag :capture_log
    test "with debug_logs", %{state: state} do
      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()

      log =
        capture_log_at_level(:debug, fn ->
          Indexer.enable_debug_logs()
          BlockFetcher.handle_info(:debug_count, state)
        end)

      assert log =~ @heading
      assert log =~ "blocks: 4"
      assert log =~ "internal transactions: 3"
      assert log =~ "logs: 3"
      assert log =~ "addresses: 31"
    end
  end

  describe "import_range/3" do
    setup :state

    setup do
      start_supervised!({Task.Supervisor, name: Explorer.Indexer.TaskSupervisor})
      AddressBalanceFetcherCase.start_supervised!()
      InternalTransactionFetcherCase.start_supervised!()
      {:ok, state} = BlockFetcher.init([])

      %{state: state}
    end

    test "with single element range that is valid imports one block", %{state: state} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      assert {:ok,
              %{
                addresses: [
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
                  }
                ],
                blocks: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<91, 40, 193, 191, 211, 161, 82, 48, 201, 164, 107, 57, 156, 208, 249, 166, 146, 13, 67, 46, 133,
                        56, 28, 198, 161, 64, 176, 110, 132, 16, 17, 47>>
                  }
                ],
                logs: [],
                transactions: []
              }} = BlockFetcher.import_range(0..0, state, sequence)

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 1
    end

    test "can import range with all synchronous imported schemas", %{state: state} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)

      assert {:ok,
              %{
                addresses: [
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes:
                      <<139, 243, 141, 71, 100, 146, 144, 100, 242, 212, 211, 165, 101, 32, 167, 106, 179, 223, 65, 91>>
                  },
                  %Explorer.Chain.Hash{
                    byte_count: 20,
                    bytes:
                      <<232, 221, 197, 199, 162, 210, 240, 215, 169, 121, 132, 89, 192, 16, 79, 223, 94, 152, 122, 202>>
                  }
                ],
                blocks: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<246, 180, 184, 200, 141, 243, 235, 210, 82, 236, 71, 99, 40, 51, 77, 192, 38, 207, 102, 96, 106,
                        132, 251, 118, 155, 61, 60, 188, 204, 132, 113, 189>>
                  }
                ],
                logs: [
                  %{
                    index: 0,
                    transaction_hash: %Explorer.Chain.Hash{
                      byte_count: 32,
                      bytes:
                        <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                          101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                    }
                  }
                ],
                transactions: [
                  %Explorer.Chain.Hash{
                    byte_count: 32,
                    bytes:
                      <<83, 189, 136, 72, 114, 222, 62, 72, 134, 146, 136, 27, 174, 236, 38, 46, 123, 149, 35, 77, 57,
                        101, 36, 140, 57, 254, 153, 47, 255, 212, 51, 229>>
                  }
                ]
              }} = BlockFetcher.import_range(@first_full_block_number..@first_full_block_number, state, sequence)

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 2
      assert Repo.aggregate(Log, :count, :id) == 1
      assert Repo.aggregate(Transaction, :count, :hash) == 1
    end

    test "can import `call_type` `create` internal transactions", %{state: state} do
      {:ok, sequence} = Sequence.start_link([], 0, 1)
      block_number = 2870099

      assert {:ok,
               %{
                 addresses: [
                   %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<55, 82, 240, 165, 33, 178, 227, 131, 105, 63, 101,
                       141, 111, 195, 119, 149, 48, 36, 194, 7>>
                   },
                   %Explorer.Chain.Hash{
                     byte_count: 20,
                     bytes: <<160, 176, 212, 204, 244, 131, 176, 0, 240, 175, 89,
                       196, 122, 25, 68, 102, 132, 119, 185, 65>>
                   }
                 ],
                 blocks: [
                   %Explorer.Chain.Hash{
                     byte_count: 32,
                     bytes: <<115, 101, 178, 91, 36, 120, 185, 193, 76, 155, 12,
                       166, 110, 7, 162, 206, 118, 128, 146, 242, 99, 197, 63, 43,
                       31, 239, 124, 92, 106, 217, 227, 236>>
                   }
                 ],
                 logs: [],
                 transactions: [
                   %Explorer.Chain.Hash{
                     byte_count: 32,
                     bytes: <<220, 233, 56, 150, 137, 221, 195, 160, 253, 201, 52,
                       242, 66, 31, 219, 120, 159, 168, 126, 215, 1, 160, 105,
                       252, 52, 74, 105, 114, 243, 165, 82, 234>>
                   } = transaction_hash
                 ]
               }} = BlockFetcher.import_range(block_number..block_number, state, sequence)

      assert {:ok, ^transaction_hash} = Hash.Full.cast("0xdce9389689ddc3a0fdc934f2421fdb789fa87ed701a069fc344a6972f3a552ea")

      wait_for_tasks(InternalTransactionFetcher)
      wait_for_tasks(AddressBalanceFetcher)

      assert Repo.aggregate(Block, :count, :hash) == 1
      assert Repo.aggregate(Address, :count, :hash) == 3
      assert Repo.aggregate(Log, :count, :id) == 0
      assert Repo.aggregate(Transaction, :count, :hash) == 1
      assert Repo.aggregate(InternalTransaction, :count, :id) == 1

      internal_transaction = Repo.one!(InternalTransaction)

      assert internal_transaction.type == :create
      assert internal_transaction.call_type == nil
    end
  end

  defp capture_log_at_level(level, block) do
    logger_level_transaction(fn ->
      Logger.configure(level: level)

      capture_log(fn ->
        block.()
        Process.sleep(10)
      end)
    end)
  end

  defp logger_level_transaction(block) do
    level_before = Logger.level()

    on_exit(fn ->
      Logger.configure(level: level_before)
    end)

    return = block.()

    Logger.configure(level: level_before)

    return
  end

  defp state(_) do
    {:ok, state} = BlockFetcher.init([])

    %{state: state}
  end

  defp wait_until(timeout, producer) do
    parent = self()
    ref = make_ref()

    spawn(fn -> do_wait_until(parent, ref, producer) end)

    receive do
      {^ref, :ok} -> :ok
    after
      timeout -> exit(:timeout)
    end
  end

  defp do_wait_until(parent, ref, producer) do
    if producer.() do
      send(parent, {ref, :ok})
    else
      :timer.sleep(100)
      do_wait_until(parent, ref, producer)
    end
  end

  defp wait_for_tasks(buffered_task) do
    wait_until(5000, fn ->
      counts = Explorer.BufferedTask.debug_count(buffered_task)
      counts.buffer == 0 and counts.tasks == 0
    end)
  end
end
