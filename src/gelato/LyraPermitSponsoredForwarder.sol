// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable, Context} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC2771Context} from "../../lib/relay-context-contracts/contracts/vendor/ERC2771Context.sol";

import {ISocketVault} from "../interfaces/ISocketVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {ILightAccountFactory} from "../interfaces/ILightAccountFactory.sol";

/**
 * @title  LyraPermitSponsoredForwarder
 * @notice Use this contract to allow gasless transactions, we sponsor the gas for users
 *
 */
contract LyraPermitSponsoredForwarder is Ownable, ERC2771Context {
    ///@dev SocketVault address.
    address public immutable socketVault;

    ///@dev local token address. This token must support permit
    address public immutable token;

    ///@dev Light Account factory address.
    address public constant lightAccountFactory = 0x000000893A26168158fbeaDD9335Be5bC96592E2;

    struct PermitData {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(address _token, address _socketVault)
        payable
        ERC2771Context(0xd8253782c45a12053594b9deB72d8e8aB2Fca54c)
    {
        token = _token;
        socketVault = _socketVault;

        IERC20(_token).approve(_socketVault, type(uint256).max);
    }

    /**
     * @notice  Deposit USDC to L2 through socket bridge. Gas is paid in token
     * @dev     Users never have to approve USDC to this contract.
     * @param isScwWallet   True if user wants to deposit to default LightAccount on L2. False if the user wants to deposit to its own L2 address
     * @param minGasLimit   Minimum gas limit for the L2 execution
     * @param connector     Socket Connector
     * @param permitData   Data and signatures for permit
     */
    function depositGasless(bool isScwWallet, uint32 minGasLimit, address connector, PermitData calldata permitData)
        external
        payable
    {
        address msgSender = _msgSender();

        // use try catch so that others cannot grief by submitting the same permit data before this tx
        try IERC20Permit(token).permit(
            msgSender, address(this), permitData.value, permitData.deadline, permitData.v, permitData.r, permitData.s
        ) {} catch {}

        IERC20(token).transferFrom(msgSender, address(this), permitData.value);

        uint256 socketFee = ISocketVault(socketVault).getMinFees(connector, minGasLimit);

        // Pay socket fee and deposit to Lyra Chain
        ISocketVault(socketVault).depositToAppChain{value: socketFee}(
            _getL2Receiver(msgSender, isScwWallet), permitData.value, minGasLimit, connector
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

    function _msgSender() internal view override(Context, ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    receive() external payable {}
}
