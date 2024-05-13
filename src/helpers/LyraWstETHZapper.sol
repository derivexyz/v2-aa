// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";
import {ILightAccountFactory} from "../interfaces/ILightAccountFactory.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IWstETH} from "../interfaces/wstETH/IWstETH.sol";
import {IStETH} from "../interfaces/wstETH/IStETH.sol";
import {IWETH} from "../interfaces/IWETH.sol";

/**
 * @title  LyraWstETHZapper
 * @dev    Helper contract to wrap ETH/WETH/stETH into Lido wstETH, and then deposit to lyra chain via socket bridge.
 */
contract LyraWstETHZapper is Ownable {
    IWETH public immutable weth;
    IWstETH public immutable wstETH;
    IStETH public immutable stETH;

    ///@dev Light Account factory address.
    address public constant lightAccountFactory = 0x000000893A26168158fbeaDD9335Be5bC96592E2;

    constructor(address _weth, address _wstETH) Ownable() {
        weth = IWETH(_weth);
        wstETH = IWstETH(_wstETH);
        stETH = IStETH(wstETH.stETH());
    }

    function recover(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
        _returnAllEth();
    }

    function estimateWstethReceived(
        uint256 amountEth,
        address socketVault,
        uint256 gasLimit,
        address connector,
        bool takeOutFee
    ) external view returns (uint256) {
        uint256 socketFee = 0;
        if (takeOutFee) {
            socketFee = ISocketVault(socketVault).getMinFees(connector, gasLimit);
        }
        uint256 depositAmount = amountEth - socketFee;
        return wstETH.stETH().getSharesByPooledEth(depositAmount);
    }

    ///////////////////////////
    // ETH and WETH deposits //
    ///////////////////////////
    /**
     * @notice Wrap ETH into wstETH and deposit to Lyra Chain via socket vault
     */
    function zapETH(address socketVault, bool isSCW, uint256 gasLimit, address connector) external payable {
        _wrapETHAndDeposit(socketVault, isSCW, gasLimit, connector);
    }

    /**
     * @notice Wrap ETH into wstETH and deposit to Lyra Chain via socket vault
     */
    function zapWETH(uint256 amount, address socketVault, bool isSCW, uint256 gasLimit, address connector)
        external
        payable
    {
        // unrwap weth to eth
        weth.transferFrom(msg.sender, address(this), amount);
        weth.withdraw(weth.balanceOf(address(this)));

        _wrapETHAndDeposit(socketVault, isSCW, gasLimit, connector);
    }

    function _wrapETHAndDeposit(address socketVault, bool isSCW, uint256 gasLimit, address connector) internal {
        uint256 ethBalance = address(this).balance;

        uint256 socketFee = ISocketVault(socketVault).getMinFees(connector, gasLimit);
        uint256 depositAmount = ethBalance - socketFee;

        stETH.submit{value: depositAmount}(address(this));
        stETH.approve(address(wstETH), depositAmount);
        wstETH.wrap(depositAmount);

        _depositAllWstETH(socketVault, gasLimit, connector, socketFee, _getL2Receiver(isSCW));
    }

    ///////////
    // stETH //
    ///////////
    /**
     * @notice Wrap stETH into wstETH and deposit to Lyra Chain via socket vault.
     * Must pay eth as well to cover the socket fee.
     */
    function zapStETH(uint256 amount, address socketVault, bool isSCW, uint256 gasLimit, address connector)
        external
        payable
    {
        // unrwap weth to eth
        stETH.transferFrom(msg.sender, address(this), amount);
        stETH.approve(address(wstETH), amount);
        // we dont get the wstETH amount as we always just deposit balance of this contract
        wstETH.wrap(amount);

        uint256 socketFee = ISocketVault(socketVault).getMinFees(connector, gasLimit);

        // We assume the user transfers enough ETH to cover the fee. The depositToAppchain call will fail if not
        _depositAllWstETH(socketVault, gasLimit, connector, socketFee, _getL2Receiver(isSCW));
    }

    /////////////
    // Helpers //
    /////////////

    /**
     * @notice Deposit wstETH held in this contract on behalf of the sender
     */
    function _depositAllWstETH(
        address socketVault,
        uint256 gasLimit,
        address connector,
        uint256 socketFee,
        address recipient
    ) internal {
        uint256 amount = wstETH.balanceOf(address(this));
        wstETH.approve(socketVault, type(uint256).max);

        ISocketVault(socketVault).depositToAppChain{value: socketFee}(recipient, amount, gasLimit, connector);

        _returnAllEth();
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

    function _returnAllEth() internal {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Needs to be able to receive ETH from unwrapping WETH
    receive() external payable {}
}
