// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOFT, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title  LyraWithdrawWrapperV2
 * @notice Helper contract to charge token, pay socket fee and withdraw to another chain.
 *         Supports both native OFTs and OFTAdapters, as well as EVM and Solana addresses.
 */
contract LyraOFTWithdrawWrapperV2 is Ownable {
    using OptionsBuilder for bytes;
    using SafeERC20 for IERC20;

    /// @dev price of asset in wei. How many {token wei} is 1 ETH * 1e18.
    mapping(address token => uint256) public staticPrice;
    /// @dev adapter address for tokens that use OFTAdapter instead of native OFT
    mapping(address token => address adapter) public adapterForToken;
    address public feeRecipient;
    uint256 public receiveAmountFactor = 0.9e18;
    uint128 public staticGasLimit = 80000;

    constructor() payable Ownable(msg.sender) {}

    ///////////
    // Admin //
    ///////////
    function setFeeRecipient(address newRecipient) external onlyOwner {
        feeRecipient = newRecipient;
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
        for (uint256 i = 0; i < tokens.length; i++) {
            staticPrice[tokens[i]] = rates[i];
        }
    }

    function setReceiveAmountFactor(uint256 newFactor) external onlyOwner {
        receiveAmountFactor = newFactor;
    }

    function setStaticGasLimit(uint128 newGasLimit) external onlyOwner {
        staticGasLimit = newGasLimit;
    }

    /**
     * @notice Set adapter for a token that uses OFTAdapter instead of native OFT
     * @param token The token address users will interact with
     * @param adapter The OFTAdapter address
     */
    function setAdapterForToken(address token, address adapter) external onlyOwner {
        adapterForToken[token] = adapter;
    }

    ////////////
    // Public //
    ////////////
    receive() external payable {}

    /**
     * @notice Withdraw tokens to another chain (EVM address)
     * @param token The token to withdraw (either native OFT or key for adapter lookup)
     * @param amount Amount of tokens to withdraw
     * @param toAddress Destination EVM address
     * @param destEID Destination endpoint ID
     */
    function withdrawToChain(address token, uint256 amount, address toAddress, uint32 destEID) external {
        _withdrawToChain(token, amount, addressToBytes32(toAddress), destEID);
    }

    /**
     * @notice Withdraw tokens to another chain (supports Solana and other non-EVM chains)
     * @param token The token to withdraw (either native OFT or key for adapter lookup)
     * @param amount Amount of tokens to withdraw
     * @param toAddressBytes32 Destination address as bytes32 (for Solana or other chains)
     * @param destEID Destination endpoint ID
     */
    function withdrawToChainBytes32(address token, uint256 amount, bytes32 toAddressBytes32, uint32 destEID) external {
        _withdrawToChain(token, amount, toAddressBytes32, destEID);
    }

    /**
     * @dev Internal withdraw logic supporting both native OFTs and OFTAdapters
     */
    function _withdrawToChain(address token, uint256 amount, bytes32 toAddressBytes32, uint32 destEID) internal {
        address adapter = adapterForToken[token];
        bool isAdapter = adapter != address(0);

        // Determine the OFT interface to use (either direct OFT or adapter)
        IOFT sourceOFT;
        address tokenToTransfer;

        if (isAdapter) {
            // For adapters: transfer underlying token, approve adapter
            sourceOFT = IOFT(adapter);
        } else {
            // For native OFTs: transfer the OFT token directly
            sourceOFT = IOFT(token);
        }

        // Transfer tokens from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(staticGasLimit, 0);

        SendParam memory sendParam =
            SendParam(destEID, toAddressBytes32, amount, amount * receiveAmountFactor / 1e18, _extraOptions, "", "");

        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);
        uint256 tokenPrice = staticPrice[token];
        require(tokenPrice > 0, "staticPrice not set");

        if (tokenPrice != 1) {
            uint256 feeInToken = fee.nativeFee * staticPrice[token] / 1e36;
            if (feeInToken > amount) revert("withdraw amount < fee");
            IERC20(token).safeTransfer(feeRecipient == address(0) ? owner() : feeRecipient, feeInToken);

            // update amount and send param after collecting rough fee
            amount = amount - feeInToken;
            sendParam = SendParam(
                destEID, toAddressBytes32, amount, amount * receiveAmountFactor / 1e18, _extraOptions, "", ""
            );
            fee = sourceOFT.quoteSend(sendParam, false);
        }

        // For adapters, we need to approve before sending
        if (isAdapter) {
            IERC20(token).approve(adapter, amount);
        }

        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
    }

    ///////////
    // Utils //
    ///////////

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function getFeeInEth(address token, uint256 amount, uint32 destEID) public view returns (uint256) {
        uint256 tokenPrice = staticPrice[token];
        require(tokenPrice > 0, "staticPrice not set");

        address adapter = adapterForToken[token];
        IOFT sourceOFT = adapter != address(0) ? IOFT(adapter) : IOFT(token);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(staticGasLimit, 0);
        SendParam memory sendParam =
            SendParam(destEID, bytes32(0), amount, amount * receiveAmountFactor / 1e18, _extraOptions, "", "");
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);
        return fee.nativeFee;
    }

    function getFeeInToken(address token, uint256 amount, uint32 destEID) public view returns (uint256) {
        uint256 tokenPrice = staticPrice[token];
        require(tokenPrice > 0, "staticPrice not set");
        if (tokenPrice == 1) {
            return 0;
        }

        address adapter = adapterForToken[token];
        IOFT sourceOFT = adapter != address(0) ? IOFT(adapter) : IOFT(token);

        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(staticGasLimit, 0);
        SendParam memory sendParam =
            SendParam(destEID, bytes32(0), amount, amount * receiveAmountFactor / 1e18, _extraOptions, "", "");
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);
        return fee.nativeFee * tokenPrice / 1e36;
    }
}
