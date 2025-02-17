// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStakedDRV} from "../interfaces/derive/IStakedDRV.sol";

import {IntentExecutorBase} from "./IntentExecutorBase.sol";

/**
 * @title  StakeDRVIntent
 * @notice A shared contract that allows executor to help users auto stake DRV from smart wallet
 * @dev    Users who wish to have the auto-stake feature need to approve this contract to spend their DRV
 */
contract StakeDRVIntent is IntentExecutorBase {
    address public immutable DRV;
    address public immutable StakedDRV;

    event IntentStakeDRV(address indexed scw, uint256 amount);

    constructor(address _drv, address _stakedDRV) {
        DRV = _drv;
        StakedDRV = _stakedDRV;
        IERC20(DRV).approve(address(StakedDRV), type(uint256).max);
    }

    /**
     * @notice Execute a stake intent to auto stake DRV.
     * @dev    The SCW must have approved this contract to spend the token.
     * @param scw The light account address
     * @param amount The amount of DRV to stake
     */
    function executeStakeDRVIntent(address scw, uint256 amount) external onlyIntentExecutor {
        
        IERC20(DRV).transferFrom(scw, address(this), amount);
        IStakedDRV(StakedDRV).convertTo(amount, scw);
        emit IntentStakeDRV(scw, amount);
    }
}
