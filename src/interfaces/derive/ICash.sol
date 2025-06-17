// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface ICash {
    function accrueInterest() external;

    function calculateBalanceWithInterest(uint256 accountId) external returns (int256 balance);
}
