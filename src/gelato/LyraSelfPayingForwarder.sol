// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GelatoRelayContextERC2771} from "../../lib/relay-context-contracts/contracts/GelatoRelayContextERC2771.sol";

import {LyraForwarderBase} from "./LyraForwarderBase.sol";

import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";

import {IERC3009} from "../interfaces/IERC3009.sol";

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

    /**
     * @notice Deposit USDC to L2
     * @dev Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas
     * @param depositAmount Amount of USDC to deposit
     * @param l2Receiver    Address of the receiver on L2
     * @param minGasLimit   Minimum gas limit for the L2 execution
     */
    function depositUSDCNativeBridge(
        uint256 depositAmount,
        uint256 maxERC20Fee,
        address l2Receiver,
        uint32 minGasLimit,
        ReceiveWithAuthData calldata authData
    ) external onlyGelatoRelayERC2771 {
        _transferRelayFeeCapped(maxERC20Fee);

        // step 1: receive USDC from user to this contract
        IERC3009(usdcLocal).receiveWithAuthorization(
            _getMsgSender(),
            address(this),
            authData.value,
            authData.validAfter,
            authData.validBefore,
            authData.nonce,
            authData.v,
            authData.r,
            authData.s
        );

        uint256 remaining = depositAmount - _getFee();

        // step 3: call bridge to L2
        IL1StandardBridge(standardBridge).bridgeERC20To(usdcLocal, usdcRemote, l2Receiver, remaining, minGasLimit, "");
    }

    /**
     * @notice Deposit USDC to L2 through other socket fast bridge
     */
    function depositUSDCSocketBridge(
        uint256 depositAmount,
        uint256 maxERC20Fee,
        address l2Receiver,
        uint32 minGasLimit,
        address connector,
        ReceiveWithAuthData calldata authData
    ) external onlyGelatoRelayERC2771 {
        _transferRelayFeeCapped(maxERC20Fee);

        // step 1: receive USDC from user to this contract
        IERC3009(usdcLocal).receiveWithAuthorization(
            _getMsgSender(),
            address(this),
            authData.value,
            authData.validAfter,
            authData.validBefore,
            authData.nonce,
            authData.v,
            authData.r,
            authData.s
        );

        uint256 remaining = depositAmount - _getFee();

        ISocketVault(usdcSocketVault).depositToAppChain(l2Receiver, remaining, minGasLimit, connector);
    }
}
