// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IOFTWithdrawWrapper {
    function withdrawToChain(address token, uint256 amount, address toAddress, uint32 destEID) external;

    function getFeeInToken(address token, uint256 amount, uint32 destEID) external view returns (uint256);
}
