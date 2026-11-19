# Part C – Cross-Chain Messaging with LayerZero V2 (OApp)

An omnichain application (`MyOApp`) that sends a string from **OP Sepolia** to **Arbitrum Sepolia** (and back) using LayerZero V2. The receiving contract stores the last message in `lastMessage`.

## How It Works

```
OP Sepolia                                                     Arbitrum Sepolia
[MyOApp] --sendMessage--> [Endpoint] ~~> DVN verifies ~~> [Endpoint] --> [MyOApp]._lzReceive
         (_lzSend, pays fee)              Executor delivers           (checks peer, stores lastMessage)
```

1. `quoteSend` returns the fee for the message (DVN fee + executor gas on the destination chain).
2. `sendMessage` encodes the string and calls `_lzSend`, paying the fee as `msg.value` on the source chain.
3. The LayerZero Labs DVN verifies the message, and the executor calls `lzReceive` on the destination endpoint.
4. `OAppReceiver` checks that the call comes from the endpoint and that the sender is the registered peer. Only then `_lzReceive` decodes the string and stores it.

## Deployment

| | OP Sepolia | Arbitrum Sepolia |
|---|---|---|
| LayerZero EID | 40232 | 40231 |
| MyOApp address | `0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774` | `0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774` |
| Deploy tx | `0x8ee54973342ad136991ad4f7c6121d0c97b8001d7f98976dd1e2df6ff92ad2d2` | `0x68cb3c55259ec2c0a998428b8a29416f0e210f7b165aac2bf74cb36747e909fa` |
| Explorer | [sepolia-optimism.etherscan.io](https://sepolia-optimism.etherscan.io/address/0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774) | [sepolia.arbiscan.io](https://sepolia.arbiscan.io/address/0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774) |

Both contracts have the same address because a contract address is derived from the deployer address and its nonce. It was the first transaction from my dev wallet on both chains (nonce 0), so the result is identical.

```bash
npx hardhat lz:deploy --networks optimism-sepolia,arbitrum-sepolia --tags MyOApp
npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts
```

## Peers

After wiring, each OApp returns the other one as its peer (address left-padded to `bytes32`):

```bash
# OP Sepolia → peer on Arbitrum Sepolia (EID 40231)
cast call 0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774 "peers(uint32)(bytes32)" 40231 --rpc-url https://sepolia.optimism.io
0x0000000000000000000000001ca15d24f2a6ed115df255ad2802cc6db71f0774

# Arbitrum Sepolia → peer on OP Sepolia (EID 40232)
cast call 0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774 "peers(uint32)(bytes32)" 40232 --rpc-url https://sepolia-rollup.arbitrum.io/rpc
0x0000000000000000000000001ca15d24f2a6ed115df255ad2802cc6db71f0774
```

## Live Message: OP Sepolia → Arbitrum Sepolia

**1. Quote the fee**

```bash
cast call 0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774 \
  "quoteSend(uint32,string,bytes,bool)((uint256,uint256))" \
  40231 "Hello from OP" 0x false --rpc-url https://sepolia.optimism.io
(107020955524558 [1.07e14], 0)
```

The native fee is about 0.000107 ETH, the ZRO fee is 0. Options `0x` means no extra options, so only the enforced options from the config (80,000 gas for `_lzReceive`) apply.

**2. Send the message**

```bash
cast send 0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774 \
  "sendMessage(uint32,string,bytes)" 40231 "Hello from OP" 0x \
  --value 107020955524558 --account dev-wallet --rpc-url https://sepolia.optimism.io
```

| | Value |
|---|---|
| Source tx (OP Sepolia) | [`0x9b437c2987d293a7db77a5540238a0ea69881b61b76745cf6a3ac1853f10e614`](https://sepolia-optimism.etherscan.io/tx/0x9b437c2987d293a7db77a5540238a0ea69881b61b76745cf6a3ac1853f10e614) |
| Destination tx (Arbitrum Sepolia) | `<full hash from LayerZero Scan, starts with 0x99fe3c9b1c…>` |
| LayerZero Scan | [testnet.layerzeroscan.com/tx/0x9b43…e614](https://testnet.layerzeroscan.com/tx/0x9b437c2987d293a7db77a5540238a0ea69881b61b76745cf6a3ac1853f10e614) |

In the logs of the source tx, the endpoint's `PacketSent` event contains the source EID (`0x9d28` = 40232), the destination EID (`0x9d27` = 40231), the peer address, the message as hex (`48656c6c6f2066726f6d204f50` = "Hello from OP") and the enforced gas limit (`0x13880` = 80,000).

**3. Check the result on Arbitrum Sepolia**

```bash
cast call 0x1ca15D24F2A6eD115df255Ad2802CC6Db71F0774 "lastMessage()(string)" --rpc-url https://sepolia-rollup.arbitrum.io/rpc
"Hello from OP"
```

## What I Learned

- **LayerZero is not a separate chain.** Each chain has its own LayerZero Endpoint contract. My OApp hands the message to the local endpoint, DVNs verify it off-chain, and an executor delivers it to the endpoint on the destination chain, which calls my `_lzReceive`.
- **Peers are a whitelist.** `peers[eid]` stores the trusted OApp on each remote chain as `bytes32` (so non-EVM chains fit too). Only the owner can set them, and `OAppReceiver` rejects messages from any other sender. Without a peer, sending fails with `NoPeer`.
- **EIDs are not chain IDs.** LayerZero uses its own endpoint IDs (OP Sepolia = 40232, Arbitrum Sepolia = 40231).
- **Fees are paid on the source chain.** I pay in ETH on OP Sepolia for the DVN and for the gas the executor spends on Arbitrum. That is why `quoteSend` is needed before sending.
- **Options control execution on the destination.** Enforced options (set by the owner in the config) guarantee a minimum gas limit for `_lzReceive`; `combineOptions` merges them with options from the caller. Too little gas means the message arrives but cannot be executed.
- **Cross-chain messages are asynchronous.** The message was already stored on Arbitrum while LayerZero Scan still showed "Confirming".
- **Contract addresses are deterministic.** Same deployer + same nonce gives the same address on every EVM chain.

## Problems & Solutions

1. **Template was configured for Base Sepolia.** I replaced `base-sepolia` with `optimism-sepolia` (`EndpointId.OPTSEP_V2_TESTNET`) in `hardhat.config.ts` and `layerzero.config.ts`.
2. **Renaming functions broke the build.** After renaming `sendString` → `sendMessage` and `quoteSendString` → `quoteSend` (as required by the spec), `forge build` failed in the test file. The compiler errors showed the exact lines to update; the Hardhat task and test also had to be updated.
3. **Hardhat cannot use my Foundry keystore.** Deployment with Hardhat needs `PRIVATE_KEY` in `.env`. I exported it from my dev wallet keystore (`cast wallet decrypt-keystore`), used only a wallet with testnet ETH, and made sure `.env` is in `.gitignore`.
4. **Faucets required a mainnet balance.** The Alchemy and QuickNode faucets rejected my wallet because it has no mainnet ETH. I bridged Sepolia ETH instead: via Superbridge (testnet mode) to OP Sepolia and via the Arbitrum bridge to Arbitrum Sepolia. Superbridge had no route to Arbitrum because it only supports OP Stack chains.
5. **MetaMask could not connect to OP / Arbitrum Sepolia.** The default RPCs did not respond. I set `https://sepolia.optimism.io` and `https://sepolia-rollup.arbitrum.io/rpc` as RPC URLs. For checking balances, `cast balance` was more reliable anyway.
6. **Testing events across chains.** A test using `vm.expectEmit` for `MessageReceived` failed with `PacketVerified != expected MessageReceived`. `verifyPackets` makes several separate calls (DVN verify, commit, then `lzReceive`), and `expectEmit` only checks the next call. The trace showed the real LayerZero flow step by step. I removed that test and check the stored message instead.

## Testing Approach

Tests are in `test/foundry/MyOApp.t.sol` and use LayerZero's `TestHelperOz5`. It deploys two endpoints locally (chain A with EID 1, chain B with EID 2), deploys one OApp per chain, and wires them as peers in `setUp()`. `verifyPackets` plays the role of DVN and executor and delivers the message to the destination.

| Test | What it checks |
|---|---|---|
| `test_owner_isSetCorrectly` | Both OApps are owned by the deployer |
| `test_peers_areSet` | A has B as peer and B has A as peer |
| `test_quoteSend_returnsFee` | `quoteSend` returns a native fee > 0 |
| `test_sendMessage_fromAToB` | A message from A is stored in `lastMessage` on B |
| `test_sendMessage_fromBToA` | Messaging also works in the opposite direction |
| `test_sendMessage_withTooLittleFee_reverts` | Paying less than the quoted fee reverts |
| `test_setPeer_byNonOwner_reverts` | A normal user cannot change the trusted peer |

**Why these tests:** they cover the happy path in both directions, the two security-relevant rules (only the owner sets peers, fees must be paid) and the configuration that everything else depends on (peers).

**Deliberately not tested:** event emission on the destination (see Problems & Solutions #6), exact gas profiling of `_lzReceive`, and real DVN/executor behaviour, which are mocked by the TestHelper. The real end-to-end flow was tested live on OP Sepolia → Arbitrum Sepolia (see above).