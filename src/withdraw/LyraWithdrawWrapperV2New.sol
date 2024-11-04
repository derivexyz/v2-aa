// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IBridgeOld {
    function withdrawFromAppChain(address receiver_, uint256 burnAmount_, uint256 msgGasLimit_, address connector_)
        external
        payable;

    function getMinFees(address connector_, uint256 gasLimit_) external view returns (uint256);
}

interface IBridgeNew {
    function bridge(
        address receiver_,
        uint256 amount_,
        uint256 msgGasLimit_,
        address connector_,
        bytes calldata execPayload_,
        bytes calldata options_
    ) external payable;

    function getMinFees(address connector_, uint256 msgGasLimit_, uint256 payloadSize_)
        external
        view
        returns (uint256 totalFees);
}

/**
 * @title  LyraWithdrawWrapperV2
 * @notice Helper contract to charge token, pay socket fee and withdraw to another chain
 */
contract LyraWithdrawWrapperV2New is Ownable {
    enum ControllerType {
        NONE,
        NEW,
        OLD
    }

    /// @dev price of asset in wei. How many {token wei} is 1 ETH * 1e18.
    mapping(address token => uint256) public staticPrice;
    mapping(address => ControllerType) public controllerType;
    address public feeRecipient;
    uint public payloadSize = 161;

    constructor() payable {}

    ///////////
    // Admin //
    ///////////
    function setControllerType(address controller, ControllerType _controllerType) external onlyOwner {
        controllerType[controller] = _controllerType;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        feeRecipient = newRecipient;
    }

    function setPayloadSize(uint newSize) external onlyOwner {
        payloadSize = newSize;
    }

    /**
     * Get ETH out of the contract
     */
    function rescueEth() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverERC20(address token) external onlyOwner {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function setStaticRate(address token, uint256 newRate) external onlyOwner {
        staticPrice[token] = newRate;
    }

    function setStaticRates(address[] memory tokens, uint256[] memory rates) external onlyOwner {
        require(tokens.length == rates.length, "Array length mismatch");
        for (uint i = 0; i < tokens.length; i++) {
            staticPrice[tokens[i]] = rates[i];
        }
    }

    ////////////
    // Public //
    ////////////
    receive() external payable {}

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

        ControllerType controller = controllerType[socketController];
        if (controller == ControllerType.NONE) revert("Controller not set");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(socketController, amount);

        uint256 feeInToken = 0;
        // get the eth bridge fee
        uint256 minFee = getMinFee(socketController, connector, gasLimit);

        if (staticPrice[token] != 1) {
            feeInToken = minFee * staticPrice[token] / 1e36;

            if (feeInToken > amount) revert("withdraw amount < fee");

            IERC20(token).transfer(feeRecipient == address(0) ? owner() : feeRecipient, feeInToken);
        }

        uint256 remaining = amount - feeInToken;

        if (controller == ControllerType.NEW) {
            IBridgeNew(socketController).bridge{value: minFee}(
                recipient, remaining, gasLimit, connector, new bytes(0), new bytes(0)
            );
        } else {
            IBridgeOld(socketController).withdrawFromAppChain{value: minFee}(recipient, remaining, gasLimit, connector);
        }
    }

    /**
     * @dev get the estimated fee in token for a withdrawal
     */
    function getFeeInToken(address token, address controller, address connector, uint256 gasLimit)
        public
        view
        returns (uint256 feeInToken)
    {
        uint256 minFee = getMinFee(controller, connector, gasLimit);
        feeInToken = minFee * staticPrice[token] / 1e36;
    }

    function getMinFee(address socketController, address connector, uint256 gasLimit) public view returns (uint256) {
        ControllerType controller = controllerType[socketController];
        if (controller == ControllerType.NONE) revert("Controller not set");
        if (controller == ControllerType.NEW) {
            return IBridgeNew(socketController).getMinFees(connector, gasLimit, payloadSize);
        } else {
            return IBridgeOld(socketController).getMinFees(connector, gasLimit);
        }
    }
}
