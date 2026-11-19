// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MyToken – Basic ERC-20 token deployed on ZKsync Era
/// @author Adrian (github.com/thuisdev)
/// @notice A fixed-supply ERC-20 token. The full supply is minted to the
///         deployer at construction time.
/// @dev L2-2: Inherits OpenZeppelin v5 ERC20 for a battle-tested implementation
///      of the standard instead of a custom one.
contract MyToken is ERC20 {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Total supply minted to the deployer (1,000,000 tokens with 18 decimals).
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when an empty string is passed as the token name.
    error EmptyName();

    /// @notice Thrown when an empty string is passed as the token symbol.
    error EmptySymbol();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Deploys the token and mints the full supply to the deployer.
    /// @dev L2-3: Name and symbol are passed as constructor arguments at
    ///      deployment instead of being hardcoded, so the same contract can be
    ///      reused for different tokens. Reverts with EmptyName or EmptySymbol
    ///      if either argument is an empty string. Emits a Transfer event from
    ///      address(0) via _mint.
    /// @param name_   The human-readable token name (e.g. "AdrianToken").
    /// @param symbol_ The ticker symbol (e.g. "ADR").
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // L2-3: Validate the constructor arguments before minting
        if (bytes(name_).length == 0) {
            revert EmptyName();
        }
        if (bytes(symbol_).length == 0) {
            revert EmptySymbol();
        }

        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
