// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";
import {ISocketVault} from "../interfaces/ISocketVault.sol";

/**
 * @title LyraForwarder
 * @notice this contract help onboarding users with only USDC in their wallet to our custom rollup, with help of Gelato Relayer
 */
abstract contract LyraForwarderBase {
    ///@dev L1 USDC address.
    address public immutable usdcLocal;

    ///@dev L2 USDC address.
    address public immutable usdcRemote;

    ///@dev L1StandardBridge address.
    address public immutable standardBridge;

    ///@dev L1SocketVault address (fast bridge)
    address public immutable socketVault;

    struct PermitData {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(address _usdcLocal, address _usdcRemote, address _l1standardBridge, address _socketVault) {
        usdcLocal = _usdcLocal;
        usdcRemote = _usdcRemote;
        standardBridge = _l1standardBridge;
        socketVault = _socketVault;

        IERC20(_usdcLocal).approve(_l1standardBridge, type(uint256).max);
        IERC20(_usdcLocal).approve(_socketVault, type(uint256).max);
    }

    /**
     * @notice Deposit USDC to L2
     * @dev This function use _msgSender() to be compatible with ERC2771.
     *      Users can either interact directly with this contract (to do permit + deposit in one go),
     *      or sign a Gelato relay request, and let the GelatoRelay1BalanceERC2771 contract forward the call to this contract.
     *      With the latter, _msgSender() will be the signer which is verified by GelatoRelay1BalanceERC2771
     */
    function depositUSDCNativeBridge(
        PermitData calldata permit,
        uint256 depositAmount,
        address l2Receiver,
        uint32 minGasLimit
    ) external {
        // step 1 (optional) call permit (todo: use receiveWithAuthorization )
        if (permit.value != 0) {
            IERC20Permit(usdcLocal).permit(
                _msgSender(), address(this), permit.value, permit.deadline, permit.v, permit.r, permit.s
            );
        }

        // step 2: transferFrom msg.sender to this contract
        IERC20(usdcLocal).transferFrom(_msgSender(), address(this), depositAmount);

        // step 3: call bridge to L2
        IL1StandardBridge(standardBridge).bridgeERC20To(
            usdcLocal, usdcRemote, l2Receiver, depositAmount, minGasLimit, ""
        );
    }

    function depositUSDCSocketBridge(
        PermitData calldata permit,
        uint256 depositAmount,
        address l2Receiver,
        uint32 minGasLimit,
        address connector
    ) external {
        // todo: use receiveWithAuthorization
        if (permit.value != 0) {
            IERC20Permit(usdcLocal).permit(
                _msgSender(), address(this), permit.value, permit.deadline, permit.v, permit.r, permit.s
            );
        }

        IERC20(usdcLocal).transferFrom(_msgSender(), address(this), depositAmount);

        ISocketVault(socketVault).depositToAppChain(l2Receiver, depositAmount, minGasLimit, connector);
    }

    function _msgSender() internal virtual returns (address);
}
