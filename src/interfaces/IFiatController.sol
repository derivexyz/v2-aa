// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IFiatController {
  function withdrawFromAppChain(address receiver_, uint256 burnAmount_, uint256 msgGasLimit_, address connector_) external payable;

  function getMinFees(address connector_, uint256 gasLimit_) external view returns (uint256);

  // For testing

  function mintPendingFor(address receiver_, address connector_) external;

  function receiveInbound(bytes memory payload_) external;
}