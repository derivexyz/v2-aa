// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IFiatController} from "../interfaces/IFiatController.sol";

/**
 * @title  LyraWithdrawWrapper
 */
contract LyraWithdrawWrapper is Ownable {
    ///@dev L2 USDC address.
    address public immutable usdc;

    ///@dev L2 Controller address.
    address public immutable socketController;

    ///@dev static ETH / USD price controlled by owner
    uint256 public staticPrice;

    constructor(address _usdc, address _socketController, uint256 _staticRate) payable {
        usdc = _usdc;
        socketController = _socketController;

        IERC20(_usdc).approve(_socketController, type(uint256).max);

        staticPrice = _staticRate;
    }

    /**
     * @notice withdraw USDC from L2 to L1
     * @dev this function can be used by anyone to withdraw USDC from L2 to L1 who wishes to pay the Socket fee in USDC
     */
    function withdrawToL1(uint256 amount, address recipient, address connector, uint256 gasLimit) external {
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        // get fee in wei
        uint256 minFee = IFiatController(socketController).getMinFees(connector, gasLimit);

        uint256 feeInUSDC = minFee * staticPrice / 1e30;

        if (feeInUSDC > amount) revert("withdraw amount < fee");

        uint256 remaining = amount - feeInUSDC;

        IERC20(usdc).transfer(owner(), feeInUSDC);

        IFiatController(socketController).withdrawFromAppChain{value: minFee}(recipient, remaining, gasLimit, connector);
    }

    /**
     * @dev get the estimated fee in USDC for a withdrawal
     */
    function getFeeUSDC(address connector, uint256 gasLimit) public view returns (uint256 feeInUSDC) {
        uint256 minFee = IFiatController(socketController).getMinFees(connector, gasLimit);
        feeInUSDC = minFee * staticPrice / 1e30;
    }

    /**
     * Get ETH out of the contract
     */
    function rescueEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setStaticRate(uint256 newRate) external onlyOwner {
        staticPrice = newRate;
    }

    receive() external payable {}
}
