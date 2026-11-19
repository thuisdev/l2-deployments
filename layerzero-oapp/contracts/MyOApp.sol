// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// L2-11: OApp is imported from LayerZero's devtools (@layerzerolabs/oapp-evm).
import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title MyOApp – Cross-chain string messenger built on LayerZero V2
/// @author Adrian (github.com/thuisdev)
/// @notice Sends a string from one chain to the same OApp on another chain and
///         stores the last received string.
/// @dev Deployed on OP Sepolia and Arbitrum Sepolia. Peers, DVNs and enforced
///      options are configured via layerzero.config.ts and `lz:oapp:wire`.
contract MyOApp is OApp, OAppOptionsType3 {
    // -------------------------------------------------------------------------
    // Constants & State
    // -------------------------------------------------------------------------

    /// @notice Message type used to look up enforced options for sendMessage.
    uint16 public constant SEND = 1;

    /// @notice Last string received from any remote chain.
    string public lastMessage;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a message is sent to another chain.
    /// @param dstEid  Destination endpoint ID.
    /// @param sender  Address that called sendMessage on this chain.
    /// @param message The message that was sent.
    event MessageSent(uint32 indexed dstEid, address indexed sender, string message);

    /// @notice Emitted when a message is received from another chain.
    /// @param srcEid  Source endpoint ID.
    /// @param sender  The peer OApp on the source chain (bytes32).
    /// @param message The message that was received.
    event MessageReceived(uint32 indexed srcEid, bytes32 indexed sender, string message);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @notice Connects the OApp to the local LayerZero endpoint and sets the owner.
    /// @dev The owner is the only account allowed to set peers and options.
    /// @param endpoint_ The LayerZero Endpoint V2 address on this chain.
    /// @param owner_    The address permitted to configure this OApp.
    constructor(address endpoint_, address owner_) OApp(endpoint_, owner_) Ownable(owner_) {}

    // -------------------------------------------------------------------------
    // External: state-changing
    // -------------------------------------------------------------------------

    // L2-12: Sends a cross-chain message via _lzSend.
    /// @notice Sends a string to the peer OApp on the destination chain.
    /// @dev Emits MessageSent. msg.value must cover the fee returned by quoteSend;
    ///      any excess is refunded to the caller. Reverts with NoPeer if no peer
    ///      is set for dstEid (L2-13).
    /// @param dstEid  Destination endpoint ID.
    /// @param message The string to send.
    /// @param options Extra execution options (e.g. lzReceive gas); use 0x for none.
    function sendMessage(uint32 dstEid, string calldata message, bytes calldata options) external payable {
        bytes memory payload = abi.encode(message);

        // L2-14: combineOptions merges the owner's enforced options with the caller's options.
        _lzSend(
            dstEid, payload, combineOptions(dstEid, SEND, options), MessagingFee(msg.value, 0), payable(msg.sender)
        );

        emit MessageSent(dstEid, msg.sender, message);
    }

    // -------------------------------------------------------------------------
    // Public: view
    // -------------------------------------------------------------------------

    // L2-14: Estimates the messaging fee before sending.
    /// @notice Returns the fee required to send `message` to `dstEid`.
    /// @dev Uses the same payload and combined options as sendMessage, so the
    ///      quoted fee matches the real cost.
    /// @param dstEid       Destination endpoint ID.
    /// @param message      The string to send.
    /// @param options      Extra execution options (e.g. lzReceive gas); use 0x for none.
    /// @param payInLzToken True to quote the fee in ZRO, false to quote in native gas.
    /// @return fee The native fee and ZRO fee for the message.
    function quoteSend(uint32 dstEid, string calldata message, bytes calldata options, bool payInLzToken)
        public
        view
        returns (MessagingFee memory fee)
    {
        bytes memory payload = abi.encode(message);

        // L2-14: Same combined options as in sendMessage.
        fee = _quote(dstEid, payload, combineOptions(dstEid, SEND, options), payInLzToken);
    }

    // -------------------------------------------------------------------------
    // Internal
    // -------------------------------------------------------------------------

    // L2-12: Receives a cross-chain message via _lzReceive.
    // L2-13: OAppReceiver only calls this if the caller is the LayerZero endpoint
    //        and origin.sender is the registered peer for origin.srcEid.
    /// @notice Stores an incoming message from the peer OApp.
    /// @dev Emits MessageReceived. guid, executor and extraData are not needed here.
    /// @param origin  Source chain ID, sender (peer) and nonce of the message.
    /// @param payload ABI-encoded string sent by sendMessage.
    function _lzReceive(
        Origin calldata origin,
        bytes32, /* guid */
        bytes calldata payload,
        address, /* executor */
        bytes calldata /* extraData */
    ) internal override {
        string memory message = abi.decode(payload, (string));

        lastMessage = message;

        emit MessageReceived(origin.srcEid, origin.sender, message);
    }
}
