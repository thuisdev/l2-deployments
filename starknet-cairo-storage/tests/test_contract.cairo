// L2-10: Unit tests for the set and get functions of SimpleStorage using snforge.

use simple_storage::{ISimpleStorageDispatcher, ISimpleStorageDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

/// Helper: declares and deploys a fresh SimpleStorage contract for each test.
fn deploy_contract() -> ContractAddress {
    let contract = declare("SimpleStorage").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

/// Helper: deploys a contract and returns a dispatcher to call its functions.
fn setup() -> ISimpleStorageDispatcher {
    let contract_address = deploy_contract();
    ISimpleStorageDispatcher { contract_address }
}

// L2-10: get before any set returns the default value 0.
#[test]
fn test_get_value_initial_returns_zero() {
    let dispatcher = setup();

    assert(dispatcher.get_value() == 0, 'Initial value should be 0');
}

// L2-10: set stores a value, get returns it.
#[test]
fn test_set_value_then_get_returns_value() {
    let dispatcher = setup();

    dispatcher.set_value(42);

    assert(dispatcher.get_value() == 42, 'Value should be 42');
}

// L2-10: a second set overwrites the first value.
#[test]
fn test_set_value_twice_overwrites() {
    let dispatcher = setup();

    dispatcher.set_value(42);
    dispatcher.set_value(100);

    assert(dispatcher.get_value() == 100, 'Value should be overwritten');
}

// L2-10: setting 0 is allowed and resets the stored value.
#[test]
fn test_set_value_zero_is_allowed() {
    let dispatcher = setup();

    dispatcher.set_value(42);
    dispatcher.set_value(0);

    assert(dispatcher.get_value() == 0, 'Value should be reset to 0');
}

// L2-10: felt252 can also hold short strings (short string literal).
#[test]
fn test_set_value_short_string() {
    let dispatcher = setup();

    dispatcher.set_value('hello');

    assert(dispatcher.get_value() == 'hello', 'Value should be hello');
}