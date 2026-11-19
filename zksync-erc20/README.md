# Part A – ERC-20 Token on ZKsync Era (Sepolia)

A fixed-supply ERC-20 token (`AdrianToken`, `ADR`) built on OpenZeppelin v5 and deployed + verified on ZKsync Era Sepolia.

## Deployment

| | Value |
|---|---|
| Network | ZKsync Era Sepolia (chain ID 300) |
| Contract address | `0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774` |
| Deploy tx | `0x822f7c82f47a6bd329d3518f1355c7d7d0b380f3f29da99f9806d1b22a776ecf` |
| Verified contract (ZKsync explorer) | [sepolia.explorer.zksync.io](https://sepolia.explorer.zksync.io/address/0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774) |
| Contract on the explorer named in the spec | [sepolia-era.zksync.network](https://sepolia-era.zksync.network/address/0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774) |
| Constructor args | `"AdrianToken"`, `"ADR"` |
| Initial supply | 1,000,000 ADR (18 decimals), minted to the deployer |

> **Note on verification:** The contract is verified on the official ZKsync block explorer. It was deployed as EVM bytecode via ZKsync's EVM Bytecode Interpreter.

## Setup & Commands

```bash
# Install dependencies (installed without git submodules, see Problems & Solutions)
forge install OpenZeppelin/openzeppelin-contracts foundry-rs/forge-std --no-git

# Build & test
forge build
forge test

# Deploy to ZKsync Era Sepolia
forge script script/DeployMyToken.s.sol \
  --account dev-wallet \
  --sender <DEPLOYER_ADDRESS> \
  --rpc-url https://sepolia.era.zksync.dev \
  --chain 300 \
  --broadcast \
  --skip-simulation
```

Verification was done through the ZKsync explorer UI with these settings:
Compilation target `EVM`, Solidity `v0.8.24`, optimizer `off`, EVM version `cancun`, flattened source (`forge flatten`), ABI-encoded constructor arguments (`cast abi-encode "constructor(string,string)" "AdrianToken" "ADR"`).

## What I Learned

- **How bridging L1 → L2 actually works.** The bridge transaction on Sepolia is just a normal contract call to the ZKsync bridge contract (`requestL2TransactionDirect`, with chain ID 300 in the input data). My ETH is locked on L1, and ZKsync credits the same amount on L2. Deposits L1 → L2 take minutes; withdrawals L2 → L1 would have to wait until the ZK proof is verified on L1.
- **ZK rollups vs. optimistic rollups.** Optimistic rollups assume batches are valid and allow a ~7-day challenge window; ZK rollups submit a validity proof that L1 verifies immediately.
- **EraVM vs. EVM on ZKsync.** ZKsync runs its own VM (EraVM). Older tooling (`foundry-zksync`, `zksolc`) compiled Solidity to native EraVM bytecode. Today ZKsync also runs standard EVM bytecode through an EVM Bytecode Interpreter, so normal Foundry works.
- **How contract verification works.** The explorer recompiles the source with the exact same settings and compares the result with the on-chain bytecode. Because the compiler is deterministic, every setting has to match: compiler version, optimizer, EVM version and constructor arguments.
- **Fixed supply as a design decision.** Minting the full supply in the constructor means no one can ever create new tokens. A mintable token would need an owner and access control. Fixed supply is simpler and needs less trust.

## Problems & Solutions

1. **`foundry-zksync` could not be installed on Windows.** The installer downloaded a file that was not a valid zip archive, and `forge build --zksync` was rejected by standard Foundry. The ZKsync docs now list `foundry-zksync` as legacy tooling and recommend standard Ethereum tooling via the EVM Bytecode Interpreter, so I switched to plain Foundry. `forge script` then needed `--skip-simulation`, because Foundry's local EVM simulation can underestimate gas on EraVM.
2. **Verification failed at first.** I pasted the `cast abi-encode` command into the constructor-arguments field instead of its hex output. Then I checked the real build settings with `forge config`: the optimizer was off (not on, as the form defaulted to) and `evm_version` was `osaka`. Solc 0.8.24 does not support `osaka`, so Foundry had compiled for `cancun`. With those settings the verification succeeded.

## Testing Approach

Tests are in `test/MyToken.t.sol` and run with `forge test`.

| Test | Why |
|---|---|
| `test_constructor_validArgs_setsNameAndSymbol` | Proves L2-3: name and symbol come from the constructor arguments |
| `test_constructor_validArgs_mintsSupplyToDeployer` | The deployer receives the full fixed supply and `totalSupply` matches |
| `test_decimals_default_returns18` | Confirms the OpenZeppelin default of 18 decimals |
| `test_constructor_emptyName_revertsEmptyName` | Input validation: an empty name must revert with `EmptyName` |
| `test_constructor_emptySymbol_revertsEmptySymbol` | Input validation: an empty symbol must revert with `EmptySymbol` |
| `test_transfer_validAmount_updatesBalances` | Happy path for transfers: balances update correctly |
| `test_transfer_insufficientBalance_reverts` | An account without tokens cannot transfer |
| `testFuzz_transfer_anyValidAmount_conservesSupply` | Fuzz test: for any valid amount, no tokens are created or destroyed by a transfer |