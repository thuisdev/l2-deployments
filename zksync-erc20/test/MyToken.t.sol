// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {MyToken} from "../src/MyToken.sol";

/// @title MyTokenTest – Unit tests for MyToken
/// @notice Covers constructor arguments, initial supply, input validation and transfers.
contract MyTokenTest is Test {
    MyToken private _token;

    address private constant ALICE = address(0xA11CE);
    address private constant BOB = address(0xB0B);

    /// @notice Deploys a fresh token before each test, with this test contract as deployer.
    function setUp() public {
        _token = new MyToken("AdrianToken", "ADR");
    }

    /// @notice L2-3: Name and symbol come from the constructor arguments.
    function test_constructor_validArgs_setsNameAndSymbol() public view {
        assertEq(_token.name(), "AdrianToken");
        assertEq(_token.symbol(), "ADR");
    }

    /// @notice The deployer receives the full initial supply.
    function test_constructor_validArgs_mintsSupplyToDeployer() public view {
        assertEq(_token.totalSupply(), _token.INITIAL_SUPPLY());
        assertEq(_token.balanceOf(address(this)), _token.INITIAL_SUPPLY());
    }

    /// @notice Decimals stay at the OpenZeppelin default of 18.
    function test_decimals_default_returns18() public view {
        assertEq(_token.decimals(), 18);
    }

    /// @notice Deployment reverts if the name is empty.
    function test_constructor_emptyName_revertsEmptyName() public {
        vm.expectRevert(MyToken.EmptyName.selector);
        new MyToken("", "ADR");
    }

    /// @notice Deployment reverts if the symbol is empty.
    function test_constructor_emptySymbol_revertsEmptySymbol() public {
        vm.expectRevert(MyToken.EmptySymbol.selector);
        new MyToken("AdrianToken", "");
    }

    /// @notice A transfer moves the balance from sender to recipient.
    function test_transfer_validAmount_updatesBalances() public {
        uint256 amount = 100e18;

        _token.transfer(ALICE, amount);

        assertEq(_token.balanceOf(ALICE), amount);
        assertEq(_token.balanceOf(address(this)), _token.INITIAL_SUPPLY() - amount);
    }

    /// @notice A transfer above the sender's balance reverts.
    function test_transfer_insufficientBalance_reverts() public {
        vm.prank(ALICE); // Alice has 0 tokens
        vm.expectRevert();
        _token.transfer(BOB, 1);
    }

    /// @notice Fuzz: any amount up to the supply can be transferred, and total supply stays constant.
    /// @param amount Random amount provided by the fuzzer.
    function testFuzz_transfer_anyValidAmount_conservesSupply(uint256 amount) public {
        amount = bound(amount, 0, _token.INITIAL_SUPPLY());

        _token.transfer(ALICE, amount);

        assertEq(_token.balanceOf(ALICE) + _token.balanceOf(address(this)), _token.totalSupply());
    }
}
