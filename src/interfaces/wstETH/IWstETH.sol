// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStETH} from "./IStETH.sol";

interface IWstETH is IERC20 {
    function stETH() external view returns (IStETH);
    function wrap(uint256 _stETHAmount) external returns (uint256 wstETHAmount);
}
