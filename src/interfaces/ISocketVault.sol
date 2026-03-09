// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface ISocketVault {
    function depositToAppChain(address receiver_, uint256 amount_, uint256 msgGasLimit_, address connector_)
        external
        payable;

    function __token() external view returns (address);

    function getMinFees(address connector, uint256 minGasLimit) external view returns (uint256);
}

interface ISocketVaultV2 {
    function bridge(
        address receiver_,
        uint256 amount_,
        uint256 msgGasLimit_,
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_
    ) external payable;

    function token() external view returns (address);

    function getMinFees(address connector, uint256 minGasLimit, uint256 payloadSize) external view returns (uint256);
}
