// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IStakedDRV is IERC20 {
    function convertTo(uint256 amount, address to) external;
}
