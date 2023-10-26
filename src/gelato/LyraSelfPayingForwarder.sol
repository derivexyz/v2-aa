// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GelatoRelayContextERC2771} from "../../lib/relay-context-contracts/contracts/GelatoRelayContextERC2771.sol";

import {LyraForwarderBase} from "./LyraForwarderBase.sol";

/**
 * @title  LyraSelfPayingForwarder
 * @notice Use this contract to allow gasless transactions, but users pay for their own gas with ERC20s
 * @dev    This contract can only be called by GELATO_RELAY_ERC2771 or GELATO_RELAY_CONCURRENT_ERC2771
 */
contract LyraSelfPayingForwarder is LyraForwarderBase, GelatoRelayContextERC2771 {
    constructor(address _usdcLocal, address _usdcRemote, address _bridge, address _socketVault)
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge, _socketVault)
        GelatoRelayContextERC2771()
    {}

    function _msgSender() internal view override returns (address) {
        return GelatoRelayContextERC2771._getMsgSender();
    }
}
