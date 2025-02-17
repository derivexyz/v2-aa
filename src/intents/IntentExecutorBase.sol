// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  IntentExecutorBase
 * @notice A shared contract that allows authorized EOAs to execute intents
 */
contract IntentExecutorBase is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice Whether the account is an intent executor
     */
    mapping(address => bool) public isIntentExecutor;

    /**
     * @notice The error emitted when the caller is not an intent executor
     */
    error NotIntentExecutor();

    /**
     * @notice The event emitted when an intent executor is set
     */
    event IntentExecutorSet(address indexed executor, bool isIntentExecutor);

    /**
     * @notice Set an EOA as an intent executor
     * @param _executor The EOA address
     * @param _isIntentExecutor Whether the EOA is an intent executor
     */
    function setIntentExecutor(address _executor, bool _isIntentExecutor) external onlyOwner {
        isIntentExecutor[_executor] = _isIntentExecutor;

        emit IntentExecutorSet(_executor, _isIntentExecutor);
    }

    /**
     * @notice Allow owner to transfer any token out of the contract
     * @param token The address of the token to rescue
     */
    function rescueToken(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice Verify that the caller is an intent executor
     */
    function _verifyIntentExecutor() internal view {
        if (!isIntentExecutor[msg.sender]) revert NotIntentExecutor();
    }

    modifier onlyIntentExecutor() {
        _verifyIntentExecutor();
        _;
    }
}
