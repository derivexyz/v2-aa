// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC2771Context} from "../../lib/relay-context-contracts/contracts/vendor/ERC2771Context.sol";
import {LyraForwarderBase} from "./LyraForwarderBase.sol";
import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";

import {IERC3009} from "../interfaces/IERC3009.sol";

/**
 * @title LyraForwarder
 * @notice use this contract when we want to sponsor gas for users
 */
contract LyraSponsoredForwarder is LyraForwarderBase, ERC2771Context {
    /**
     * @param _trustedForwarder GelatoRelay1BalanceERC2771 forwarder (0xd8253782c45a12053594b9deB72d8e8aB2Fca54c) for all non-zkSync-EVM
     */
    constructor(address _trustedForwarder, address _usdcLocal, address _usdcRemote, address _bridge)
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge)
        ERC2771Context(_trustedForwarder)
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
        address l2Receiver,
        uint32 minGasLimit,
        ReceiveWithAuthData calldata authData
    ) external {
        // step 1: receive USDC from user to this contract
        IERC3009(usdcLocal).receiveWithAuthorization(
            _msgSender(),
            address(this),
            authData.value,
            authData.validAfter,
            authData.validBefore,
            authData.nonce,
            authData.v,
            authData.r,
            authData.s
        );

        // step 3: call bridge to L2
        IL1StandardBridge(standardBridge).bridgeERC20To(
            usdcLocal, usdcRemote, l2Receiver, depositAmount, minGasLimit, ""
        );
    }

    /**
     * @notice Deposit USDC to L2 through other socket fast bridge
     */
    function depositUSDCSocketBridge(
        address socketVault,
        uint256 depositAmount,
        address l2Receiver,
        uint32 minGasLimit,
        address connector,
        ReceiveWithAuthData calldata authData
    ) external {
        // step 1: receive USDC from user to this contract
        IERC3009(usdcLocal).receiveWithAuthorization(
            _msgSender(),
            address(this),
            authData.value,
            authData.validAfter,
            authData.validBefore,
            authData.nonce,
            authData.v,
            authData.r,
            authData.s
        );

        ISocketVault(socketVault).depositToAppChain(l2Receiver, depositAmount, minGasLimit, connector);
    }
}
