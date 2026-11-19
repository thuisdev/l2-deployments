// L2-5: Simple storage system that stores and retrieves a felt252 value.

/// Interface of the SimpleStorage contract.
/// `ref self` = can modify storage, `self: @` = read-only.
#[starknet::interface]
pub trait ISimpleStorage<TContractState> {
    /// Stores a new value, overwriting the old one.
    fn set_value(ref self: TContractState, new_value: felt252);
    /// Returns the currently stored value.
    fn get_value(self: @TContractState) -> felt252;
}

// L2-7: Comments explain each function and storage item.
/// Contract that stores a single felt252 value on Starknet.
#[starknet::contract]
mod SimpleStorage {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    // L2-6: #[storage] defines the contract's persistent state.
    #[storage]
    struct Storage {
        /// The stored value (0 until set_value is called).
        value: felt252,
    }

    // L2-6: #[external] / #[view] from early Cairo 1.0 were replaced.
    // #[abi(embed_v0)] exposes these functions, and the `self` type decides
    // external (ref self) vs. view (self: @).
    #[abi(embed_v0)]
    impl SimpleStorageImpl of super::ISimpleStorage<ContractState> {
        /// External: overwrites the stored value with new_value.
        fn set_value(ref self: ContractState, new_value: felt252) {
            self.value.write(new_value);
        }

        /// View: returns the stored value without changing state.
        fn get_value(self: @ContractState) -> felt252 {
            self.value.read()
        }
    }
}