// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {GelatoRelayContextERC2771} from "../../lib/relay-context-contracts/contracts/GelatoRelayContextERC2771.sol";

import {LyraForwarderBase} from "./LyraForwarderBase.sol";

/**
 * @title LyraForwarder
 * @notice this contract help onboarding users with only USDC in their wallet to our custom rollup, with help of Gelato Relayer
 */
contract LyraSelfPayingForwarder is LyraForwarderBase, GelatoRelayContextERC2771 {
    /**
     * @param _trustedForwarder GelatoRelay1BalanceERC2771 forwarder (0xd8253782c45a12053594b9deB72d8e8aB2Fca54c) for all non-zkSync-EVM
     */
    constructor(address _trustedForwarder, address _usdcLocal, address _usdcRemote, address _bridge)
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge)
        GelatoRelayContextERC2771(_trustedForwarder)
    {}

    function _msgSender() internal view override(LyraForwarderBase, GelatoRelayContextERC2771) returns (address) {
        return GelatoRelayContextERC2771._msgSender();
    }
}
