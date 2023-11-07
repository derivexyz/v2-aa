// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {GelatoRelayContextERC2771} from "../../lib/relay-context-contracts/contracts/GelatoRelayContextERC2771.sol";

import {LyraForwarderBase} from "./LyraForwarderBase.sol";

import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";

import {IERC3009} from "../interfaces/IERC3009.sol";

/**
 * @title  LyraSelfPayingForwarder
 * @notice Use this contract to allow gasless transactions, users pay gelato relayers with USDC
 *
 * @dev    All functions are guarded with onlyGelatoRelayERC2771. They should only be called by GELATO_RELAY_ERC2771 or GELATO_RELAY_CONCURRENT_ERC2771
 * @dev    Someone need to fund this contract with ETH to use Socket Bridge
 */
contract LyraSelfPayingForwarder is LyraForwarderBase, GelatoRelayContextERC2771 {
    constructor(
        address _usdcLocal,
        address _usdcRemote,
        address _bridge,
        address _socketVault,
        address _socketConnector
    )
        payable
        LyraForwarderBase(_usdcLocal, _usdcRemote, _bridge, _socketVault, _socketConnector)
        GelatoRelayContextERC2771()
    {}

    /**
     * @notice Deposit USDC to L2
     * @dev Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas
     * @param maxFeeUSDC    Maximum USDC fee that user is willing to pay
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2
     * @param minGasLimit   Minimum gas limit for the L2 execution
     */
    function depositUSDCNativeBridge(
        uint256 maxFeeUSDC,
        bool isScwWallet,
        uint32 minGasLimit,
        ReceiveWithAuthData calldata authData
    ) external onlyGelatoRelayERC2771 {
        address msgSender = _getMsgSender();

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

        // Pay gelato fee, reverts if exceeded maxFeeUSDC
        _transferRelayFeeCapped(maxFeeUSDC);

        uint256 remaining = authData.value - _getFee();

        IL1StandardBridge(standardBridge).bridgeERC20To(
            usdcLocal, usdcRemote, _getL2Receiver(msgSender, isScwWallet), remaining, minGasLimit, ""
        );
    }

    /**
     * @notice Deposit USDC to L2 through other socket fast bridge. Gas is paid in USDC
     * @dev Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas
     * @param maxFeeUSDC    Maximum USDC fee that user is willing to pay
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2. False if user wants to deposit to its own L2 address
     * @param minGasLimit   Minimum gas limit for the L2 execution
     * @param authData      Data and signatures for receiveWithAuthorization
     */
    function depositUSDCSocketBridge(
        uint256 maxFeeUSDC,
        bool isScwWallet,
        uint32 minGasLimit,
        ReceiveWithAuthData calldata authData
    ) external onlyGelatoRelayERC2771 {
        address msgSender = _getMsgSender();

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

        // Pay gelato fee, reverts if exceeded maxFeeUSDC
        _transferRelayFeeCapped(maxFeeUSDC);

        uint256 remaining = authData.value - _getFee();

        uint256 socketFee = ISocketVault(socketVault).getMinFees(socketConnector, minGasLimit);

        // Pay socket fee and deposit to Lyra Chain
        ISocketVault(socketVault).depositToAppChain{value: socketFee}(
            _getL2Receiver(msgSender, isScwWallet), remaining, minGasLimit, socketConnector
        );
    }

    receive() external payable {}
}
