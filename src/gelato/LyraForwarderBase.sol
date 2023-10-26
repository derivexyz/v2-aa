// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title  LyraForwarder
 * @notice This contract help onboarding users with only USDC in their wallet to our custom rollup, with help of Gelato Relayer
 * @dev    All functions use _msgSender() to be compatible with ERC2771.
 *         Users never have to approve USDC to this contract, we use receiveWithAuthorization to save gas on USDC
 */
abstract contract LyraForwarderBase {
    // keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    ///@dev L1 USDC address.
    address public immutable usdcLocal;

    ///@dev L2 USDC address.
    address public immutable usdcRemote;

    ///@dev L1StandardBridge address.
    address public immutable standardBridge;

    struct ReceiveWithAuthData {
        uint256 value;
        uint256 validAfter;
        uint256 validBefore;
        bytes32 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(address _usdcLocal, address _usdcRemote, address _l1standardBridge) {
        usdcLocal = _usdcLocal;
        usdcRemote = _usdcRemote;
        standardBridge = _l1standardBridge;

        IERC20(_usdcLocal).approve(_l1standardBridge, type(uint256).max);
    }
}
