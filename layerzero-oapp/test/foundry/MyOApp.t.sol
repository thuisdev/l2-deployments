// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// L2-16: Foundry tests using LayerZero's TestHelperOz5.
//        The helper simulates two chains (A and B) locally, so no testnet is needed.

import {MyOApp, MessagingFee} from "../../contracts/MyOApp.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

/// @title MyOAppTest – Simple tests for sending messages between two chains
contract MyOAppTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    // Two simulated chains
    uint32 private aEid = 1;
    uint32 private bEid = 2;

    // One OApp on each chain
    MyOApp private aOApp;
    MyOApp private bOApp;

    // A normal user who sends messages
    address private user = address(0x1);

    // L2-14: Options = 200k gas for _lzReceive on the destination chain
    bytes private options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

    /// @notice Runs before every test: create 2 chains, deploy 2 OApps, connect them.
    function setUp() public virtual override {
        vm.deal(user, 100 ether);

        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        aOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[aEid]), address(this))));
        bOApp = MyOApp(_deployOApp(type(MyOApp).creationCode, abi.encode(address(endpoints[bEid]), address(this))));

        // L2-13: Set A and B as peers of each other
        address[] memory oapps = new address[](2);
        oapps[0] = address(aOApp);
        oapps[1] = address(bOApp);
        this.wireOApps(oapps);
    }

    /// @notice The test contract is the owner of both OApps.
    function test_owner_isSetCorrectly() public view {
        assertEq(aOApp.owner(), address(this));
        assertEq(bOApp.owner(), address(this));
    }

    /// @notice L2-13: A knows B as its peer, and B knows A.
    function test_peers_areSet() public view {
        assertEq(aOApp.peers(bEid), addressToBytes32(address(bOApp)));
        assertEq(bOApp.peers(aEid), addressToBytes32(address(aOApp)));
    }

    /// @notice L2-14: quoteSend returns a fee greater than 0.
    function test_quoteSend_returnsFee() public view {
        MessagingFee memory fee = aOApp.quoteSend(bEid, "Hello", options, false);

        assertGt(fee.nativeFee, 0);
    }

    /// @notice L2-12: A message sent from A arrives on B.
    function test_sendMessage_fromAToB() public {
        MessagingFee memory fee = aOApp.quoteSend(bEid, "Hello B", options, false);

        vm.prank(user);
        aOApp.sendMessage{value: fee.nativeFee}(bEid, "Hello B", options);

        // Deliver the message to chain B
        verifyPackets(bEid, addressToBytes32(address(bOApp)));

        assertEq(bOApp.lastMessage(), "Hello B");
    }

    /// @notice L2-12: A message sent from B arrives on A.
    function test_sendMessage_fromBToA() public {
        MessagingFee memory fee = bOApp.quoteSend(aEid, "Hello A", options, false);

        vm.prank(user);
        bOApp.sendMessage{value: fee.nativeFee}(aEid, "Hello A", options);

        // Deliver the message to chain A
        verifyPackets(aEid, addressToBytes32(address(aOApp)));

        assertEq(aOApp.lastMessage(), "Hello A");
    }

    /// @notice L2-14: Sending with too little fee fails.
    function test_sendMessage_withTooLittleFee_reverts() public {
        MessagingFee memory fee = aOApp.quoteSend(bEid, "Hello", options, false);

        vm.prank(user);
        vm.expectRevert();
        aOApp.sendMessage{value: fee.nativeFee - 1}(bEid, "Hello", options);
    }

    /// @notice L2-13: A normal user cannot change the peer.
    function test_setPeer_byNonOwner_reverts() public {
        vm.prank(user);
        vm.expectRevert();
        aOApp.setPeer(bEid, addressToBytes32(user));
    }
}
