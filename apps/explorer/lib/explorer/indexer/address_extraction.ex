defmodule Explorer.Indexer.AddressExtraction do
  @moduledoc """
  Extract Addresses from data fetched from the Blockchain and structured as Blocks, InternalTransactions,
  Transactions and Logs.

  Address hashes are present in the Blockchain as a reference of a person that made/received an
  operation in the network. In the POA Explorer it's treated like a entity, such as the ones mentioned
  above.

  This module is responsible for collecting the hashes that are present as attributes in the already
  strucutured entities and structuring them as a list of unique Addresses.

  ## Attributes

  *@entity_to_extract_format_list*

  Defines a rule of where any attributes should be collected `:from` the input and how it should be
  mapped `:to` as a new attribute.

  For example:

      %{
        blocks: [
          [
            %{from: :block_number, to: :fetched_balance_block_number},
            %{from: :miner_hash, to: :hash}
          ],
        # ...
      }

  The structure above means any item in `blocks` list that has a `:miner_hash` attribute should
  be mapped to a `hash` Address attribute.

  Each item in the `List`s relates to a single Address. So, having more than one attribute definition
  within an inner `List` means that the attributes are considered part of the same Address.

  For example:

      %{
        internal_transactions: [
          ...,
          [
            %{from: :block_number, to: :fetched_balance_block_number},
            %{from: :created_contract_address_hash, to: :hash},
            %{from: :created_contract_code, to: :contract_code}
          ]
        ]
      }
  """

  @entity_to_extract_format_list %{
    blocks: [
      [
        %{from: :number, to: :fetched_balance_block_number},
        %{from: :miner_hash, to: :hash}
      ]
    ],
    internal_transactions: [
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :from_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :created_contract_address_hash, to: :hash},
        %{from: :created_contract_code, to: :contract_code}
      ]
    ],
    transactions: [
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :from_address_hash, to: :hash}
      ],
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :to_address_hash, to: :hash}
      ]
    ],
    logs: [
      [
        %{from: :block_number, to: :fetched_balance_block_number},
        %{from: :address_hash, to: :hash}
      ]
    ]
  }

  @typedoc """
  Parameters for `Explorer.Chain.Address.changeset/2`.
  """
  @type params :: %{
          required(:hash) => String.t(),
          required(:fetched_balance_block_number) => non_neg_integer(),
          optional(:contract_code) => String.t()
        }

  defstruct pending: false

  @doc """
  Extract addresses from block, internal transaction, transaction, and log parameters.

  Blocks have their `miner_hash` extracted.

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     blocks: [
      ...>       %{
      ...>         miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         number: 34
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_balance_block_number: 34,
          hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca"
        }
      ]

  Internal transactions can have their `from_address_hash`, `to_address_hash` and/or `created_contract_address_hash`
  extracted.

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000002"
      ...>       },
      ...>       %{
      ...>         block_number: 3,
      ...>         created_contract_address_hash: "0x0000000000000000000000000000000000000003",
      ...>         created_contract_code: "0x"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          fetched_balance_block_number: 2,
          hash: "0x0000000000000000000000000000000000000002"
        },
        %{
          contract_code: "0x",
          fetched_balance_block_number: 3,
          hash: "0x0000000000000000000000000000000000000003"
        }
      ]

  Transactions can have their `from_address_hash` and/or `to_address_hash` extracted.

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001",
      ...>         to_address_hash: "0x0000000000000000000000000000000000000002"
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000003"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001"
        },
        %{
          fetched_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000002"
        },
        %{
          fetched_balance_block_number: 2,
          hash: "0x0000000000000000000000000000000000000003"
        }
      ]

  Logs can have their `address_hash` extracted.

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     logs: [
      ...>       %{
      ...>         address_hash: "0x0000000000000000000000000000000000000001",
      ...>         block_number: 1
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_balance_block_number: 1,
          hash: "0x0000000000000000000000000000000000000001"
        }
      ]

  When the same address is mentioned multiple times, the greatest `block_number` is used

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     blocks: [
      ...>       %{
      ...>         miner_hash: "0x0000000000000000000000000000000000000001",
      ...>         number: 7
      ...>       },
      ...>       %{
      ...>         miner_hash: "0x0000000000000000000000000000000000000001",
      ...>         number: 6
      ...>       }
      ...>     ],
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 5,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 4,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ],
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 3,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ],
      ...>     logs: [
      ...>       %{
      ...>         address_hash: "0x0000000000000000000000000000000000000001",
      ...>         block_number: 1
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          fetched_balance_block_number: 7,
          hash: "0x0000000000000000000000000000000000000001"
        }
      ]

  When a contract is created and then used in internal transactions and transaction in the same fetched data, the
  `created_contract_code` is merged with the greatest `block_number`

      iex> Explorer.Indexer.AddressExtraction.extract_addresses(
      ...>   %{
      ...>     internal_transactions: [
      ...>       %{
      ...>         block_number: 1,
      ...>         created_contract_code: "0x",
      ...>         created_contract_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ],
      ...>     transactions: [
      ...>       %{
      ...>         block_number: 2,
      ...>         from_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       },
      ...>       %{
      ...>         block_number: 3,
      ...>         to_address_hash: "0x0000000000000000000000000000000000000001"
      ...>       }
      ...>     ]
      ...>   }
      ...> )
      [
        %{
          contract_code: "0x",
          fetched_balance_block_number: 3,
          hash: "0x0000000000000000000000000000000000000001"
        }
      ]

  All data must have some way of extracting the `fetched_balance_block_number` or an `ArgumentError` will be raised when
  none of the supported extract formats matches the params.

  A contract's code is immutable: the same address cannot be bound to different code.  As such, different code will
  cause an error as something has gone terribly wrong with the chain if different code is written to the same address.
  """
  @spec extract_addresses(%{
          optional(:blocks) => [
            %{
              required(:miner_hash) => String.t(),
              required(:number) => non_neg_integer()
            }
          ],
          optional(:internal_transactions) => [
            %{
              required(:block_number) => non_neg_integer(),
              required(:from_address_hash) => String.t(),
              optional(:to_address_hash) => String.t(),
              optional(:created_contract_address_hash) => String.t(),
              optional(:created_contract_code) => String.t()
            }
          ],
          optional(:transactions) => [
            %{
              required(:block_number) => non_neg_integer(),
              required(:from_address_hash) => String.t(),
              optional(:to_address_hash) => String.t()
            }
          ],
          optional(:logs) => [
            %{
              required(:address_hash) => String.t(),
              required(:block_number) => non_neg_integer()
            }
          ]
        }) :: [params]
  def extract_addresses(fetched_data, options \\ []) when is_map(fetched_data) and is_list(options) do
    state = struct!(__MODULE__, options)

    fetched_data
    |> reduce_fetched_data(%{}, state)
    |> Map.values()
  end

  defp reduce_fetched_data(fetched_data, initial, %__MODULE__{} = state)
       when is_map(fetched_data) and is_map(initial) do
    Enum.reduce(fetched_data, initial, fn {key, params_list}, acc ->
      # checks that developer didn't pass an unsupported key by mistake
      extract_format_list = Map.fetch!(@entity_to_extract_format_list, key)
      reduce_params_list(params_list, acc, extract_format_list, state)
    end)
  end

  defp reduce_params_list(params_list, initial, extract_format_list, %__MODULE__{} = state)
       when is_list(params_list) and is_map(initial) and is_list(extract_format_list) do
    Enum.reduce(params_list, initial, fn params, acc ->
      reduce_params(params, acc, extract_format_list, state)
    end)
  end

  defp reduce_params(params, initial, extract_format_list, %__MODULE__{} = state)
       when is_map(params) and is_map(initial) and is_list(extract_format_list) do
    {count, final} =
      Enum.reduce(extract_format_list, {0, initial}, fn extract_format, {acc_count, acc_hash_to_address_params} = acc ->
        case extract_format(params, extract_format, state) do
          {:ok, address_params} -> {acc_count + 1, update_address_params(acc_hash_to_address_params, address_params)}
          :error -> acc
        end
      end)

    if count == 0 do
      formatted_extract_format_list =
        extract_format_list
        |> Enum.with_index()
        |> Enum.map(fn {extract_format, index} -> "#{index + 1}. #{inspect(extract_format)}}" end)
        |> Enum.join("\n")

      raise ArgumentError,
            """
            No extract format matches params.

            Extract Format(s):
            #{formatted_extract_format_list}

            Params:
            #{inspect(params)}
            """
    end

    final
  end

  defp extract_format(params, [_ | _] = extract_format, %__MODULE__{pending: pending}) when is_map(params) do
    Enum.reduce_while(extract_format, {:ok, %{}}, fn %{from: params_key, to: address_params_key},
                                                     {:ok, acc_address_params} ->
      case Map.fetch(params, params_key) do
        {:ok, value} when not is_nil(value) or (address_params_key == :fetched_balance_block_number and pending) ->
          {:cont, {:ok, Map.put(acc_address_params, address_params_key, value)}}

        _ ->
          {:halt, :error}
      end
    end)
  end

  defp update_address_params(hash_to_address_params, %{hash: hash} = address_params) do
    merged_address_params =
      case Map.fetch(hash_to_address_params, hash) do
        {:ok, previous_address_params} -> merge_address_params(previous_address_params, address_params)
        :error -> address_params
      end

    Map.put(hash_to_address_params, hash, merged_address_params)
  end

  defp merge_address_params(previous_address_params, address_params) do
    Enum.reduce(
      ~w(contract_code fetched_balance_block_number hash)a,
      %{},
      &reduce_address_param(previous_address_params, address_params, &1, &2)
    )
  end

  defp reduce_address_param(first_params, second_params, key, initial)
       when is_map(first_params) and is_map(second_params) and is_atom(key) and is_map(initial) do
    reduce_address_param_value(key, Map.get(first_params, key), Map.get(second_params, key), initial)
  end

  defp reduce_address_param_value(:contract_code = key, first_value, second_value, initial) do
    case {first_value, second_value} do
      {nil, nil} ->
        initial

      {contract_code, nil} ->
        Map.put(initial, key, contract_code)

      {nil, contract_code} ->
        Map.put(initial, key, contract_code)

      {contract_code, contract_code} ->
        Map.put(initial, key, contract_code)

      {first_contract_code, second_contract_code} ->
        raise ArgumentError,
              """
              contract_code differs:

              #{first_contract_code}

              #{second_contract_code}
              """
    end
  end

  defp reduce_address_param_value(
         :fetched_balance_block_number = key,
         first_fetched_balance_block_number,
         second_fetched_balance_block_number,
         initial
       ) do
    Map.put(initial, key, max(first_fetched_balance_block_number, second_fetched_balance_block_number))
  end

  defp reduce_address_param_value(:hash = key, hash, hash, initial) do
    Map.put(initial, key, hash)
  end
end
