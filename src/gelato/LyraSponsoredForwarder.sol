// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC2771Context} from "../../lib/relay-context-contracts/contracts/vendor/ERC2771Context.sol";
import {LyraForwarderBase} from "./LyraForwarderBase.sol";
import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";
import {IERC3009} from "../interfaces/IERC3009.sol";

/**
 * @title LyraForwarder
 * @notice Use this contract when we want to sponsor gas for users
 */
contract LyraSponsoredForwarder is LyraForwarderBase, ERC2771Context {
    /**
     * @dev GelatoRelay1BalanceERC2771 forwarder (0xd8253782c45a12053594b9deB72d8e8aB2Fca54c) is used for all non-zkSync-EVM
     */
    constructor(
        address _usdcLocal,
        address _usdcRemote,
        address _bridge,
        address _socketVault,
        address _socketConnector
    )
        payable
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge, _socketVault, _socketConnector)
        ERC2771Context(0xd8253782c45a12053594b9deB72d8e8aB2Fca54c)
    {}

    receive() external payable {}

    /**
     * @notice Deposit USDC to L2
     * @dev Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas
     *
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2
     * @param minGasLimit   Minimum gas limit for the L2 execution
     * @param authData      Data and signatures for receiveWithAuthorization
     */
    function depositUSDCNativeBridge(bool isScwWallet, uint32 minGasLimit, ReceiveWithAuthData calldata authData)
        external
    {
        address msgSender = _msgSender();

        IERC3009(usdcLocal).receiveWithAuthorization(
            msgSender,
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
            usdcLocal, usdcRemote, _getL2Receiver(msgSender, isScwWallet), authData.value, minGasLimit, ""
        );
    }

    /**
     * @notice Deposit USDC to L2 through Socket fast bridge
     * @dev Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas
     *
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2
     * @param minGasLimit   Minimum gas limit for the L2 execution
     * @param authData      Data and signatures for receiveWithAuthorization
     */
    function depositUSDCSocketBridge(bool isScwWallet, uint32 minGasLimit, ReceiveWithAuthData calldata authData)
        external
    {
        address msgSender = _msgSender();

        // step 1: receive USDC from user to this contract
        IERC3009(usdcLocal).receiveWithAuthorization(
            msgSender,
            address(this),
            authData.value,
            authData.validAfter,
            authData.validBefore,
            authData.nonce,
            authData.v,
            authData.r,
            authData.s
        );

        uint256 feeInWei = ISocketVault(socketVault).getMinFees(socketConnector, minGasLimit);

        ISocketVault(socketVault).depositToAppChain{value: feeInWei}(
            _getL2Receiver(msgSender, isScwWallet), authData.value, minGasLimit, socketConnector
        );
    }
}
