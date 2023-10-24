// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC2771Context} from "../../lib/relay-context-contracts/contracts/vendor/ERC2771Context.sol";

import {LyraForwarderBase} from "./LyraForwarderBase.sol";

/**
 * @title LyraForwarder
 * @notice this contract help onboarding users with only USDC in their wallet to our custom rollup, with help of Gelato Relayer
 */
contract LyraSponsoredForwarder is LyraForwarderBase, ERC2771Context {
    /**
     * @param _trustedForwarder GelatoRelay1BalanceERC2771 forwarder (0xd8253782c45a12053594b9deB72d8e8aB2Fca54c) for all non-zkSync-EVM
     */
    constructor(address _trustedForwarder, address _usdcLocal, address _usdcRemote, address _bridge)
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge)
        ERC2771Context(_trustedForwarder)
    {}

    function _msgSender() internal view override(LyraForwarderBase, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }
}
