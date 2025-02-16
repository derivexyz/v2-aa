// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20BasedAsset} from "../interfaces/derive/IERC20BasedAsset.sol";

/**
 * @title  IntentExecutorBase
 * @notice A shared contract that allows authorized EOAs to execute intents
 */
contract IntentExecutorBase is Ownable {
    
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
