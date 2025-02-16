// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
// solhint-disable func-name-mixedcase

pragma solidity ^0.8.18;

import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

interface ISubaccounts is IERC721 {
    function getBalance(uint256 subaccountId, address asset, uint256 subId) external view returns (uint256);
}
