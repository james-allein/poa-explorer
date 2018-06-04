use Mix.Config

config :ethereum_jsonrpc,
  url: "https://sokol.poa.network",
  variant: EthereumJSONRPC.Parity

config :ethereum_jsonrpc, EthereumJSONRPC.Parity, trace_url: "https://sokol-trace.poa.network"
