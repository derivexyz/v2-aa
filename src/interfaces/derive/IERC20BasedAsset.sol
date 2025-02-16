// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20BasedAsset {
    function wrappedAsset() external view returns (IERC20Metadata);
    function deposit(uint256 recipientAccount, uint256 assetAmount) external;
    function withdraw(uint256 accountId, uint256 assetAmount, address recipient) external;
}
