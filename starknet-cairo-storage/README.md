# Part B – Simple Storage Contract in Cairo (Starknet Sepolia)

A minimal Cairo smart contract that stores a single `felt252` value with a `set_value` and a `get_value` function, tested with `snforge` and deployed to Starknet Sepolia with `sncast`.

### Note on L2-6 (`#[external]` / `#[view]`)

The spec mentions `#[external]` and `#[view]`. These attributes come from an early Cairo 1.0 version and no longer compile with current Scarb. In current Cairo:

- `#[abi(embed_v0)]` on the `impl` block exposes the functions in the contract ABI.
- The type of `self` decides the behaviour:
  - `ref self: ContractState` → may modify storage (equivalent to `#[external]`) → `set_value`
  - `self: @ContractState` → read-only snapshot (equivalent to `#[view]`) → `get_value`

## Deployment

Network: **Starknet Sepolia**

| | Value | Link |
|---|---|---|
| Contract address | `0x03a814d480ff3991a5ac8dea3d5747f96a5cf4a2949ee216dd210c965514a2e1` | [Voyager](https://sepolia.voyager.online/contract/0x03a814d480ff3991a5ac8dea3d5747f96a5cf4a2949ee216dd210c965514a2e1) |
| Deploy tx | `0x0336b8ba96bca669a0be9ed8e3230022f25c87b445514dfd449a22061073b6c4` | [Voyager](https://sepolia.voyager.online/tx/0x0336b8ba96bca669a0be9ed8e3230022f25c87b445514dfd449a22061073b6c4) |
| Class hash | `0x07c6488ea679e9ba146627904346f00d3f4ec31ecf169052361697d87005c89c` | [Voyager](https://sepolia.voyager.online/class/0x07c6488ea679e9ba146627904346f00d3f4ec31ecf169052361697d87005c89c) |
| Declare tx | `0x03ff380683439ffa0d4a204244cf10427d07564164fa0e3cd68d1589dc367549` | [Voyager](https://sepolia.voyager.online/tx/0x03ff380683439ffa0d4a204244cf10427d07564164fa0e3cd68d1589dc367549) |
| Account deploy tx | `0x0234a074fc76b97a84dc04bc61cc5278a0c8111ca99807f61124b087388c66c3` | [Voyager](https://sepolia.voyager.online/tx/0x0234a074fc76b97a84dc04bc61cc5278a0c8111ca99807f61124b087388c66c3) |

### On-chain check

| Action | Result |
|---|---|
| `invoke set_value(42)` | tx `0x07bf2c5414e51c380e3014ac339f401c27a1f77e82595eed7e8f8fd9a0a7653a` ([Voyager](https://sepolia.voyager.online/tx/0x07bf2c5414e51c380e3014ac339f401c27a1f77e82595eed7e8f8fd9a0a7653a)) |
| `call get_value` | `0x2a` (= 42), no transaction because it only reads state |

## Setup & Commands

Starknet tooling requires WSL on Windows. Tools: Scarb 2.21.0, Starknet Foundry (snforge/sncast) 0.64.1, installed via Starkup.

```bash
# Build & test
scarb build
snforge test

# Create, fund (Starknet Sepolia faucet) and deploy an account
sncast account create --network=sepolia --name=sepolia
sncast account deploy --network=sepolia --name=sepolia

# Declare the contract class, then deploy an instance of it
sncast --account=sepolia declare --contract-name=SimpleStorage --network=sepolia
sncast --account=sepolia deploy --class-hash=<CLASS_HASH> --network=sepolia

# Interact
sncast --account=sepolia invoke --contract-address=<ADDRESS> --function=set_value --arguments=42 --network=sepolia
sncast call --contract-address=<ADDRESS> --function=get_value --network=sepolia
```

## What I Learned

- **Cairo's contract structure.** Unlike Solidity, the public API is declared separately as a `trait` with `#[starknet::interface]` and implemented in an `impl` block. Storage lives in a struct marked `#[storage]` and is accessed with `.read()` and `.write()` instead of plain assignment.
- **`ref self` vs. `self: @`.** Whether a function can change state is decided by the `self` parameter, not by a keyword like `view`. This showed up again on-chain: `invoke set_value` created a transaction and cost gas, while `call get_value` returned the value without any transaction.
- **`felt252`.** Cairo's native type is a field element of about 252 bits. Short string literals in single quotes (up to 31 characters, e.g. `'hello'`) are also stored as `felt252`.
- **Native account abstraction.** On Starknet every account is a smart contract. Before deploying anything, I had to create my account, fund it and deploy the account contract itself.
- **Declare vs. deploy.** `declare` uploads the code once as a class (identified by its class hash); `deploy` creates an instance of that class. Many contracts can be deployed from one class without re-uploading the code, unlike Ethereum where each deployment sends the full bytecode.
- **ZKsync vs. Starknet.** Both are ZK rollups, but ZKsync aims for EVM compatibility (Solidity works), while Starknet uses its own VM and language (Cairo), optimised for STARK proofs.

## Problems & Solutions

1. **Starknet tooling does not run natively on Windows.** The official docs require WSL. I installed Ubuntu via `wsl --install -d Ubuntu`. (My first attempt was interrupted, and `wsl -l -v` only showed Docker's internal `docker-desktop` distribution.)
2. **Tools installed but "command not found".** I first followed the Homebrew + asdf path from the docs, but `brew` was not on my PATH, so the asdf line in `.bashrc` pointed to a missing file. I removed those lines and ran Starkup instead. After that the asdf shims existed but called `asdf`, which was still not on the PATH. Adding `~/.asdf/shims` and `/home/linuxbrew/.linuxbrew/bin` to the PATH in `.bashrc` fixed it.
3. **`set_value` added instead of overwriting.** I started from the generated `HelloStarknet` template, which increases a balance. My first version still did `write(read() + amount)`. A set function should just write the new value, so I replaced it with `write(new_value)`.
4. **Storage variable vs. parameter.** I wrote `self.value.write(self.value)` and later `self.value_`. I learned that `self.` only accesses storage, while parameters are used directly by name. Renaming the parameter to `new_value` made the difference obvious.

## Testing Approach

Tests are in `tests/test_contract.cairo` and run with `snforge test`. Each test deploys a fresh contract through a `setup()` helper, so tests cannot influence each other. The contract is called through the `ISimpleStorageDispatcher`, which Cairo generates automatically from the interface.

| Test | Why |
|---|---|
| `test_get_value_initial_returns_zero` | Defines the initial state before any `set` |
| `test_set_value_then_get_returns_value` | Happy path: set, then get returns the same value |
| `test_set_value_twice_overwrites` | Proves `set` overwrites and does not add (the bug I had in my first version) |
| `test_set_value_zero_is_allowed` | Edge case: storing 0 is allowed by design |
| `test_set_value_short_string` | `felt252` can also hold short strings such as `'hello'` |

