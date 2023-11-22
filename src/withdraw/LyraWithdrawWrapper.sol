// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IFiatController} from "../interfaces/IFiatController.sol";


/**
 * @title  LyraWithdrawWrapper
 * @notice Shared logic for both self-paying and sponsored forwarder
 */
contract LyraWithdrawWrapper is Ownable {
    
    ///@dev L2 USDC address.
    address public immutable usdc;

    ///@dev L2 Controller address.
    address public immutable socketController;

    ///@dev static ETH / USD price controlled by owner
    uint256 public staticPrice;

    struct ReceiveWithAuthData {
        uint256 value;
        uint256 validAfter;
        uint256 validBefore;
        bytes32 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(
        address _usdc,
        address _socketController,
        uint256 _staticRate
    ) payable {
        usdc = _usdc;
        socketController = _socketController;
        
        IERC20(_usdc).approve(_socketController, type(uint256).max);

        staticPrice = _staticRate;
    }

    /**
     * @dev this function can be used by anyone to withdraw USDC from L2 to L1
     */
    function withdrawToL1(uint amount, address recipient, address connector, uint256 gasLimit) external {
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        // get fee in wei
        uint minFee = IFiatController(socketController).getMinFees(connector, gasLimit);

        uint feeInUSDC = minFee * staticPrice / 1e30;

        if (feeInUSDC > amount) revert("withdraw amount < fee");

        uint remaining = amount - feeInUSDC;

        IERC20(usdc).transfer(owner(), feeInUSDC);

        IFiatController(socketController).withdrawFromAppChain{value: minFee}(recipient, remaining, gasLimit, connector);
    }

    /**
     * Get ETH out of the contract
     */
    function rescueEth() onlyOwner external {
        payable(owner()).transfer(address(this).balance);
    }

    function setStaticRate(uint newRate) onlyOwner external {
        staticPrice = newRate;
    }
 
    receive() external payable {}
}
