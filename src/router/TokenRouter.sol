// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20BasedAsset} from "../interfaces/derive/IERC20BasedAsset.sol";

/**
 * @title  TokenRouter
 * @notice A shared contract that allows authorized user to route tokens between LightAccounts and Lyra Subaccounts
 *         Features:
 *         - Auto Deposit: automatically route ERC20s in LightAccount to Derive Subaccounts
 *         - Auto Withdraw: automatically route ERC20s in SCW to withdrawal contracts
 * @dev    Users who wish to have the auto-deposit feature need to approve this contract to spend their tokens
 */
contract TokenRouter is Ownable {
    
    IERC721 public immutable subaccounts;

    error SubaccountOwnerMismatch();

    event RouteDeposit(uint256 indexed subaccountId, address indexed scw, address indexed token, uint256 amount);
    event RouteWithdraw(uint256 indexed subaccountId, address indexed scw, address indexed token, uint256 amount);

    constructor(IERC721 _subaccounts) {
        subaccounts = _subaccounts;
    }

    /**
     * @notice Route tokens to a subaccount
     * @param scw The light account address
     * @param subaccountId The Derive subaccount ID
     * @param deriveAsset The derive v2 asset address (IAsset)
     * @param amount The amount of tokens to route
     */
    function routeToSubaccount(address scw, uint256 subaccountId, address deriveAsset, uint256 amount) external onlyOwner {
        // Can only deposit to subaccounts that are owned by the SCW
        _verifySubaccountOwner(subaccountId, scw);

        IERC20 token = IERC20BasedAsset(deriveAsset).wrappedAsset();
        token.transferFrom(scw, address(this), amount);

        IERC20BasedAsset(deriveAsset).deposit(subaccountId, amount);

        emit RouteDeposit(subaccountId, scw, address(token), amount);
    }

    /**
     * @notice Route tokens to a LightAccount
     * @param token The token address
     * @param lightAccount The LightAccount address
     * @param amount The amount of tokens to route
     */
    function routeWithdraw(address token, address lightAccount, uint256 amount) external {
        
    }

    /**
     * @notice Verify that the subaccount owner is correct
     * @param subaccountId The Derive subaccount ID
     * @param scw The LightAccount address
     */
    function _verifySubaccountOwner(uint256 subaccountId, address scw) internal view {
        if (subaccounts.ownerOf(subaccountId) != scw) revert SubaccountOwnerMismatch();
    }
}
