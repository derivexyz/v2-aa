// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";
import {ILightAccountFactory} from "../interfaces/ILightAccountFactory.sol";

/**
 * @title  LyraDepositWrapper
 * @dev    Helper contract to wrap ETH into L2 WETH, or deposit any token to L2 smart contract wallet address
 */
contract LyraDepositWrapper {
    ///@dev L2 USDC address.
    address public immutable weth;

    ///@dev Light Account factory address.
    address public constant lightAccountFactory = 0x000000893A26168158fbeaDD9335Be5bC96592E2;

    constructor(address _weth) {
        weth = _weth;
    }

    /**
     * @notice Wrap ETH into WETH and deposit to Lyra Chain via socket vault
     */
    function depositETHToLyra(address socketVault, bool isSCW, uint256 gasLimit, address connector) external payable {
        uint256 socketFee = ISocketVault(socketVault).getMinFees(connector, gasLimit);

        uint256 depositAmount = msg.value - socketFee;

        IWETH(weth).deposit{value: depositAmount}();
        IERC20(weth).approve(socketVault, type(uint256).max);

        address recipient = _getL2Receiver(isSCW);

        ISocketVault(socketVault).depositToAppChain{value: socketFee}(recipient, depositAmount, gasLimit, connector);
    }

    /**
     * @notice Deposit any token to Lyra Chain via socket vault.
     * @dev This function help calculate L2 smart wallet addresses for users
     */
    function depositToLyra(
        address token,
        address socketVault,
        bool isSCW,
        uint256 amount,
        uint256 gasLimit,
        address connector
    ) external payable {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(socketVault, type(uint256).max);

        address recipient = _getL2Receiver(isSCW);

        ISocketVault(socketVault).depositToAppChain{value: msg.value}(recipient, amount, gasLimit, connector);
    }

    /**
     * @notice Return the receiver address on L2
     */
    function _getL2Receiver(bool isScwWallet) internal view returns (address) {
        if (isScwWallet) {
            return ILightAccountFactory(lightAccountFactory).getAddress(msg.sender, 0);
        } else {
            return msg.sender;
        }
    }

    receive() external payable {}
}
