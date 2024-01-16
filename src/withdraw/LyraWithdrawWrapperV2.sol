// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IFiatController} from "../interfaces/IFiatController.sol";

/**
 * @title  LyraWithdrawWrapperV2
 * @notice Helper contract to charge token, pay socket fee and withdraw to another chain
 */
contract LyraWithdrawWrapperV2 is Ownable {
    /// @dev price of asset in wei. How many {token wei} is 1 ETH * 1e18.
    mapping(address token => uint256) public staticPrice;

    constructor() payable {}

    /**
     * @notice      withdraw token from Lyra chain to another chain with Socket bridge
     * @dev         this function requires paying a fee in token
     *
     * @param token Token to withdraw, also will be used to pay fee
     * @param amount Amount of token to withdraw
     * @param recipient Recipient address on the destination chain
     * @param socketController  Socket Controller address, determine what is the destination chain.
     *                          Lyra USDC can be withdrawn as USDC or USDC.e on Arbitrum & Optimism.
     * @param connector Socket Connector address, can be fast connector / native connector ..etc
     * @param gasLimit Gas limit on the destination chain.
     */
    function withdrawToChain(
        address token,
        uint256 amount,
        address recipient,
        address socketController,
        address connector,
        uint256 gasLimit
    ) external {
        if (staticPrice[token] == 0) revert("Token price not set");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        IERC20(token).approve(socketController, amount);

        // get fee in wei
        uint256 minFee = IFiatController(socketController).getMinFees(connector, gasLimit);

        uint256 feeInToken = minFee * staticPrice[token] / 1e36;

        if (feeInToken > amount) revert("withdraw amount < fee");

        uint256 remaining = amount - feeInToken;

        IERC20(token).transfer(owner(), feeInToken);

        IFiatController(socketController).withdrawFromAppChain{value: minFee}(recipient, remaining, gasLimit, connector);
    }

    /**
     * @dev get the estimated fee in token for a withdrawal
     */
    function getFeeInToken(address token, address controller, address connector, uint256 gasLimit)
        public
        view
        returns (uint256 feeInToken)
    {
        uint256 minFee = IFiatController(controller).getMinFees(connector, gasLimit);
        feeInToken = minFee * staticPrice[token] / 1e36;
    }

    /**
     * Get ETH out of the contract
     */
    function rescueEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function setStaticRate(address token, uint256 newRate) external onlyOwner {
        staticPrice[token] = newRate;
    }

    receive() external payable {}
}
