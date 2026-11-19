// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {MyToken} from "../src/MyToken.sol";

/// @title DeployMyToken – Deployment script for MyToken on ZKsync Era
/// @author Adrian (github.com/thuisdev)
/// @notice Deploys MyToken with a name and symbol supplied at deployment time.
/// @dev L2-4: Run with --zksync --broadcast --verify against ZKsync Era Sepolia.
contract DeployMyToken is Script {
    /// @notice Token name passed to the constructor.
    string public constant TOKEN_NAME = "AdrianToken";

    /// @notice Token symbol passed to the constructor.
    string public constant TOKEN_SYMBOL = "ADR";

    /// @notice Deploys MyToken and logs its address.
    /// @dev L2-3: Name and symbol are passed as constructor arguments here,
    ///      not hardcoded in the token contract itself. Everything between
    ///      startBroadcast and stopBroadcast is sent as a real transaction.
    /// @return token The deployed MyToken instance.
    function run() external returns (MyToken token) {
        vm.startBroadcast();

        // L2-3: Constructor arguments supplied at deployment
        token = new MyToken(TOKEN_NAME, TOKEN_SYMBOL);

        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(token));
    }
}
