// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IMatching {
    function subAccountToOwner(uint256 subAccountId) external view returns (address);
}
