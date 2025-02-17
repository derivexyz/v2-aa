// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IntentExecutorBase} from "./IntentExecutorBase.sol";
import {ILightAccount} from "../interfaces/ILightAccount.sol";
import {ISocketWithdrawWrapper} from "../interfaces/derive/ISocketWithdrawWrapper.sol";
import {IOFTWithdrawWrapper} from "../interfaces/derive/IOFTWithdrawWrapper.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  WithdrawBridgeIntent
 * @notice A shared contract that allows executor to help users to withdraw tokens from LightAccount off Derive through bridges
 * @dev    Users who wish to have the auto-withdraw feature need to approve this contract to spend their tokens
 *
 * @dev    Trust Assumptions:
 *         - Users must trust the executor not to arbitrarily execute withdrawals.
 *         - Users must trust the owner to not add malicious executor
 *         - Users rely on executors to provide a valid maxFee for each action to avoid being charged high fees by bridges.
 */
contract WithdrawBridgeIntent is IntentExecutorBase {
    using SafeERC20 for IERC20;

    ISocketWithdrawWrapper public immutable SOCKET_BRIDGE;

    IOFTWithdrawWrapper public immutable IOFT_BRIDGE;

    error InvalidRecipient();
    error FeeTooHigh();

    event IntentWithdrawSocket(
        address indexed scw,
        address indexed token,
        uint256 amount,
        address recipient,
        address controller,
        address connector
    );

    event IntentWithdrawLZ(
        address indexed scw, address indexed token, uint256 amount, address recipient, uint32 destEID
    );

    constructor(ISocketWithdrawWrapper _socketBridge, IOFTWithdrawWrapper _iOFTBridge) {
        SOCKET_BRIDGE = _socketBridge;
        IOFT_BRIDGE = _iOFTBridge;
    }

    /**
     * @notice Execute a withdraw intent to auto bridge tokens off Derive.
     * @dev    The SCW must have approved this contract to spend the token.
     * @param scw The light account address
     * @param token The ERC20 token address
     * @param amount The amount of tokens to withdraw
     * @param recipient The recipient address, must specify explicitly as the SCW owner
     * @param controller The Socket Controller address
     * @param connector The Socket Connector address
     */
    function executeWithdrawIntentSocket(
        address scw,
        address token,
        uint256 amount,
        uint256 maxFee,
        address recipient,
        address controller,
        address connector,
        uint256 gasLimit
    ) external onlyIntentExecutor {
        IERC20(token).safeTransferFrom(scw, address(this), amount);
        IERC20(token).safeApprove(address(SOCKET_BRIDGE), amount);

        if (maxFee > 0) {
            uint256 feeInToken = SOCKET_BRIDGE.getFeeInToken(token, controller, connector, gasLimit);
            if (feeInToken > maxFee) revert FeeTooHigh();
        }

        // The recipient must be the owner of the SCW
        if (ILightAccount(scw).owner() != recipient) {
            revert InvalidRecipient();
        }

        SOCKET_BRIDGE.withdrawToChain(token, amount, recipient, controller, connector, gasLimit);

        emit IntentWithdrawSocket(scw, token, amount, recipient, controller, connector);
    }

    /**
     * @notice Execute a withdraw intent to auto bridge tokens off Derive through LayerZero OFT Wrapper.
     * @dev    The SCW must have approved this contract to spend the token.
     * @param scw The light account address
     * @param token The ERC20 token address
     * @param amount The amount of tokens to withdraw
     * @param maxFee The maximum fee for the withdraw bridge
     * @param recipient The recipient address, must specify explicitly as the SCW owner
     * @param destEID The destination EID
     */
    function executeWithdrawIntentLZ(
        address scw,
        address token,
        uint256 amount,
        uint256 maxFee,
        address recipient,
        uint32 destEID
    ) external onlyIntentExecutor {
        IERC20(token).safeTransferFrom(scw, address(this), amount);
        IERC20(token).safeApprove(address(IOFT_BRIDGE), amount);

        if (maxFee > 0) {
            uint256 feeInToken = IOFT_BRIDGE.getFeeInToken(token, amount, destEID);
            if (feeInToken > maxFee) revert FeeTooHigh();
        }

        // The recipient must be the owner of the SCW
        if (ILightAccount(scw).owner() != recipient) {
            revert InvalidRecipient();
        }

        IOFT_BRIDGE.withdrawToChain(token, amount, recipient, destEID);

        emit IntentWithdrawLZ(scw, token, amount, recipient, destEID);
    }
}
