// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface ISocketVault {
    function depositToAppChain(address receiver_, uint256 amount_, uint256 msgGasLimit_, address connector_) external;

    function __token() external view returns (address);
}
