// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GelatoRelayContextERC2771} from "../../lib/relay-context-contracts/contracts/GelatoRelayContextERC2771.sol";

import {ISocketVault} from "../interfaces/ISocketVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ILightAccountFactory} from "../interfaces/ILightAccountFactory.sol";

/**
 * @title  LyraPermitBridgeForwarder
 * @notice Use this contract to allow gasless transactions, users pay gelato relayers in tokens like (USDC.e)
 *
 * @dev    All functions are guarded with onlyGelatoRelayERC2771. They should only be called by GELATO_RELAY_ERC2771 or GELATO_RELAY_CONCURRENT_ERC2771
 * @dev    Someone need to fund this contract with ETH to use Socket Bridge
 */
contract LyraPermitBridgeForwarder is Ownable, GelatoRelayContextERC2771 {
    ///@dev SocketVault address.
    address public immutable socketVault;

    ///@dev local token address. This token must support permit
    address public immutable token;

    ///@dev Light Account factory address.
    ///     See this script for more info https://github.com/alchemyplatform/light-account/blob/main/script/Deploy_LightAccountFactory.s.sol
    address public constant lightAccountFactory = 0x000000893A26168158fbeaDD9335Be5bC96592E2;

    struct PermitData {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(address _token, address _socketVault) payable GelatoRelayContextERC2771() {
        token = _token;
        socketVault = _socketVault;
    }

    /**
     * @notice  Deposit USDC to L2 through socket bridge. Gas is paid in token
     * @dev     Users never have to approve USDC to this contract.
     * @param maxFeeToken   Maximum fee in that user is willing to pay
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2. False if the user wants to deposit to its own L2 address
     * @param minGasLimit   Minimum gas limit for the L2 execution
     * @param connector     Socket Connector
     * @param permitData   Data and signatures for permit
     */
    function depositGasless(
        uint256 maxFeeToken,
        bool isScwWallet,
        uint32 minGasLimit,
        address connector,
        PermitData calldata permitData
    ) external payable onlyGelatoRelayERC2771 {
        address msgSender = _getMsgSender();

        // use try catch so that others cannot grief by submitting the same permit data before this tx
        try IERC20Permit(token).permit(
            msgSender, address(this), permitData.value, permitData.deadline, permitData.v, permitData.r, permitData.s
        ) {} catch {}

        IERC20(token).transferFrom(msgSender, address(this), permitData.value);

        // Pay gelato fee, reverts if exceeded max fee
        _transferRelayFeeCapped(maxFeeToken);

        uint256 remaining = permitData.value - _getFee();

        uint256 socketFee = ISocketVault(socketVault).getMinFees(connector, minGasLimit);

        // Pay socket fee and deposit to Lyra Chain
        ISocketVault(socketVault).depositToAppChain{value: socketFee}(
            _getL2Receiver(msgSender, isScwWallet), remaining, minGasLimit, connector
        );
    }

    /**
     * @notice Return the receiver address on L2
     */
    function _getL2Receiver(address msgSender, bool isScwWallet) internal view returns (address) {
        if (isScwWallet) {
            return ILightAccountFactory(lightAccountFactory).getAddress(msgSender, 0);
        } else {
            return msgSender;
        }
    }

    /**
     * @dev  Owner can withdraw ETH deposited to cover socket protocol fee
     */
    function withdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
