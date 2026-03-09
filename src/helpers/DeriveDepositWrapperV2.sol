// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISocketVaultV2} from "../interfaces/ISocketVault.sol";
import {ILightAccountFactory} from "../interfaces/ILightAccountFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  DeriveDepositWrapperV2
 * @dev    Helper contract to wrap ETH into L2 WETH, or deposit any token to L2 smart contract wallet address
 */
contract DeriveDepositWrapperV2 is Ownable {
    ///@dev L2 USDC address.
    address public immutable weth;

    ///@dev Light Account factory address.
    address public constant lightAccountFactory = 0x000000893A26168158fbeaDD9335Be5bC96592E2;

    constructor(address _weth) Ownable(msg.sender) {
        weth = _weth;
    }

    function recoverERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function recoverETH(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    /**
     * @notice Wrap ETH into WETH and deposit to Lyra Chain via socket vault
     */
    function depositETHToLyra(address socketVault, bool isSCW, uint256 gasLimit, address connector) external payable {
        uint256 socketFee = ISocketVaultV2(socketVault).getMinFees(connector, gasLimit, 161);

        uint256 depositAmount = msg.value - socketFee;

        IWETH(weth).deposit{value: depositAmount}();
        IERC20(weth).approve(socketVault, depositAmount);

        address recipient = _getL2Receiver(isSCW);

        ISocketVaultV2(socketVault).bridge{value: socketFee}(
            recipient, depositAmount, gasLimit, connector, new bytes(0), new bytes(0)
        );
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
        IERC20(token).approve(socketVault, amount);

        address recipient = _getL2Receiver(isSCW);
        uint256 socketFee = ISocketVaultV2(socketVault).getMinFees(connector, gasLimit, 161);

        ISocketVaultV2(socketVault).bridge{value: socketFee}(
            recipient, amount, gasLimit, connector, new bytes(0), new bytes(0)
        );
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
