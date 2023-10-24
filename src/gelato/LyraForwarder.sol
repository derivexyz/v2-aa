// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC2771Context} from "../../lib/relay-context-contracts/contracts/vendor/ERC2771Context.sol";

import {IERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IL1StandardBridge} from "../interfaces/IL1StandardBridge.sol";

/**
 * @title LyraForwarder
 * @notice this contract help onboarding users with only USDC in their wallet to our custom rollup, with help of Gelato Relayer
 */
contract LyraForwarder is ERC2771Context {
    ///@dev L1 USDC address.
    address public immutable usdcLocal;

    ///@dev L2 USDC address.
    address public immutable usdcRemote;

    ///@dev L1StandardBridge address.
    address public immutable bridge;

    struct PermitData {
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @param _trustedForwarder GelatoRelay1BalanceERC2771 forwarder (0xd8253782c45a12053594b9deB72d8e8aB2Fca54c) for all non-zkSync-EVM
     *
     */
    constructor(address _trustedForwarder, address _usdcLocal, address _usdcRemote, address _bridge)
        ERC2771Context(_trustedForwarder)
    {
        usdcLocal = _usdcLocal;
        usdcRemote = _usdcRemote;
        bridge = _bridge;

        IERC20(_usdcLocal).approve(bridge, type(uint256).max);
    }

    /**
     * @notice Deposit USDC to L2
     * @dev This function use _msgSender() to be compatible with ERC2771.
     *      Users can either interact directly with this contract (to do permit + deposit in one go),
     *      or sign a Gelato relay request, and let the GelatoRelay1BalanceERC2771 contract forward the call to this contract.
     *      With the latter, _msgSender() will be the signer which is verified by GelatoRelay1BalanceERC2771
     */
    function forwardUSDCToL2(PermitData calldata permit, uint256 depositAmount, address l2Receiver, uint32 minGasLimit)
        external
    {
        // step 1 (optional) call permit (todo: use receiveWithAuthorization )
        if (permit.value != 0) {
            IERC20Permit(usdcLocal).permit(
                _msgSender(), address(this), permit.value, permit.deadline, permit.v, permit.r, permit.s
            );
        }

        // step 2: transferFrom msg.sender to this contract
        IERC20(usdcLocal).transferFrom(_msgSender(), address(this), depositAmount);

        // step 3: call bridge to L2 (todo: change to use socket bridge)
        IL1StandardBridge(bridge).bridgeERC20To(usdcLocal, usdcRemote, l2Receiver, depositAmount, minGasLimit, "");
    }
}
