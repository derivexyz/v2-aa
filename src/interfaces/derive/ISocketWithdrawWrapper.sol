// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISocketWithdrawWrapper {
    function withdrawToChain(
        address token,
        uint256 amount,
        address recipient,
        address socketController,
        address connector,
        uint256 gasLimit
    ) external;

    function getFeeInToken(address token, address controller, address connector, uint256 gasLimit)
        external
        view
        returns (uint256);
}
