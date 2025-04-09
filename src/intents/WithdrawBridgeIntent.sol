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

    ISocketWithdrawWrapper public immutable SOCKET_WITHDRAW_WRAPPER;

    IOFTWithdrawWrapper public immutable IOFT_WITHDRAW_WRAPPER;

    /// @dev Width of each bucket in seconds
    uint64 public bucketWidth;
    /// @dev The last time a bucket started
    uint64 public lastBucketStart;
    /// @dev Maximum number of withdrawals per bucket
    uint128 public maxWithdrawPerBucket;
    /// @dev Number of withdrawals for the current bucket
    uint128 public withdrawCount;

    error InvalidRecipient();
    error FeeTooHigh();
    error WithdrawLimitReached();

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

    event BucketParamsSet(uint64 bucketWidth, uint128 maxWithdrawPerBucket);

    constructor(ISocketWithdrawWrapper _socketBridge, IOFTWithdrawWrapper _iOFTBridge) {
        SOCKET_WITHDRAW_WRAPPER = _socketBridge;
        IOFT_WITHDRAW_WRAPPER = _iOFTBridge;
    }

    /**
     * @notice Set the bucket parameters
     * @param _bucketWidth The width of each bucket in seconds
     * @param _maxWithdrawPerBucket The maximum number of withdrawals per bucket
     */
    function setBucketParams(uint64 _bucketWidth, uint128 _maxWithdrawPerBucket) external onlyOwner {
        bucketWidth = _bucketWidth;
        maxWithdrawPerBucket = _maxWithdrawPerBucket;

        emit BucketParamsSet(_bucketWidth, _maxWithdrawPerBucket);
    }

    /**
     * @notice Check if the current withdraw limit is exceeded
     * @return true if the withdraw limit is exceeded, false otherwise
     */
    function isWithdrawLimitReached() external view returns (bool) {
        if (block.timestamp >= lastBucketStart + bucketWidth) return false;

        return withdrawCount >= maxWithdrawPerBucket;
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
        _checkAndUpdateWithdrawCount();

        IERC20(token).safeTransferFrom(scw, address(this), amount);
        IERC20(token).safeApprove(address(SOCKET_WITHDRAW_WRAPPER), amount);

        if (maxFee != type(uint256).max) {
            uint256 feeInToken = SOCKET_WITHDRAW_WRAPPER.getFeeInToken(token, controller, connector, gasLimit);
            if (feeInToken > maxFee) revert FeeTooHigh();
        }

        // The recipient must be the owner of the SCW
        if (ILightAccount(scw).owner() != recipient) {
            revert InvalidRecipient();
        }

        SOCKET_WITHDRAW_WRAPPER.withdrawToChain(token, amount, recipient, controller, connector, gasLimit);

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
        _checkAndUpdateWithdrawCount();

        IERC20(token).safeTransferFrom(scw, address(this), amount);
        IERC20(token).safeApprove(address(IOFT_WITHDRAW_WRAPPER), amount);

        if (maxFee != type(uint256).max) {
            uint256 feeInToken = IOFT_WITHDRAW_WRAPPER.getFeeInToken(token, amount, destEID);
            if (feeInToken > maxFee) revert FeeTooHigh();
        }

        // The recipient must be the owner of the SCW
        if (ILightAccount(scw).owner() != recipient) {
            revert InvalidRecipient();
        }

        IOFT_WITHDRAW_WRAPPER.withdrawToChain(token, amount, recipient, destEID);

        emit IntentWithdrawLZ(scw, token, amount, recipient, destEID);
    }

    /**
     * @dev check that the number of withdrawals for the current bucket is less than the maximum
     */
    function _checkAndUpdateWithdrawCount() internal {
        if (block.timestamp >= lastBucketStart + bucketWidth) {
            lastBucketStart = uint64(block.timestamp);
            withdrawCount = 0;
        }

        withdrawCount++;

        if (withdrawCount > maxWithdrawPerBucket) revert WithdrawLimitReached();
    }
}
