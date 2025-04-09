// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IntentExecutorBase} from "./IntentExecutorBase.sol";
import {ISubaccounts} from "../interfaces/ISubaccounts.sol";
import {IERC20BasedAsset} from "../interfaces/derive/IERC20BasedAsset.sol";
import {IMatching} from "../interfaces/derive/IMatching.sol";
import {IStandardManager} from "../interfaces/derive/IStandardManager.sol";
import {IPMRM2} from "../interfaces/derive/IPMRM2.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title  SubaccountDepositIntent
 * @notice A shared contract that allows authorized user to deposit LightAccount tokens into Derive Subaccounts
 * @dev    Users who wish to have the auto-deposit feature need to approve this contract to spend their tokens
 */
contract SubaccountDepositIntent is IntentExecutorBase {
    using SafeERC20 for IERC20;

    /// @dev The matching contract user deposits their subaccounts into to trade on Derive.
    IMatching public immutable MATCHING;

    /// @dev Derive Subaccounts
    ISubaccounts public immutable SUBACCOUNTS;

    /// @dev Special derive asset that's the base unit of the manager accounting system.
    address public immutable CASH;

    error SubaccountOwnerMismatch();
    error DeriveAssetNotAllowed();

    event IntentDeposit(uint256 indexed subaccountId, address indexed scw, address indexed token, uint256 amount);
    event ManagerTypeSet(address indexed manager, uint256 indexed managerType);

    // The type of manager that is allowed to be used
    enum ManagerType {
        None,
        Standard,
        PM2
    }

    // Derive v2 asset addresses that are allowed to be deposited for intent executors
    mapping(address manager => ManagerType) public managerTypes;

    constructor(IMatching _matching, address _cash) {
        MATCHING = _matching;

        SUBACCOUNTS = ISubaccounts(_matching.subAccounts());

        CASH = _cash;
    }

    /**
     * @notice Route tokens to a subaccount
     * @param scw The light account address
     * @param subaccountId The Derive subaccount ID
     * @param deriveAsset The derive v2 asset address (IAsset)
     * @param amount The amount of tokens to route
     */
    function executeDepositIntent(address scw, uint256 subaccountId, address deriveAsset, uint256 amount)
        external
        onlyIntentExecutor
    {
        // Can only deposit to subaccounts that are owned by the SCW
        _verifySubaccountOwner(subaccountId, scw);

        // Can only deposit to derive v2 assets that are allowed
        if (!_isAllowedDeriveAsset(subaccountId, deriveAsset)) revert DeriveAssetNotAllowed();

        IERC20 token = IERC20BasedAsset(deriveAsset).wrappedAsset();
        token.safeTransferFrom(scw, address(this), amount);
        token.safeApprove(address(deriveAsset), amount);

        IERC20BasedAsset(deriveAsset).deposit(subaccountId, amount);

        emit IntentDeposit(subaccountId, scw, address(token), amount);
    }

    /**
     * @notice Verify that the subaccount owner is correct
     * @param subaccountId The Derive subaccount ID
     * @param scw The LightAccount address
     */
    function _verifySubaccountOwner(uint256 subaccountId, address scw) internal view {
        if (MATCHING.subAccountToOwner(subaccountId) != scw) revert SubaccountOwnerMismatch();
    }

    /**
     * @notice Set the allowed derive v2 asset
     * @param manager The derive v2 manager
     * @param managerType The type of manager
     */
    function setManagerTypes(address manager, ManagerType managerType) external onlyOwner {
        managerTypes[manager] = managerType;

        emit ManagerTypeSet(manager, uint256(managerType));
    }

    /**
     * @notice Check if the derive asset is valid given a subaccountId
     * @dev   We first check if the subaccountId is managed by a legitimate manager, then based on manager type,
     *        read the allowed derive asset list
     * @param subaccountId subaccount ID
     * @param deriveAsset address of the derive asset
     */
    function _isAllowedDeriveAsset(uint256 subaccountId, address deriveAsset) internal view returns (bool) {
        if (deriveAsset == CASH) return true;

        address manager = SUBACCOUNTS.manager(subaccountId);

        ManagerType managerType = managerTypes[manager];

        if (managerType == ManagerType.None) {
            return false;
        } else if (managerType == ManagerType.Standard) {
            IStandardManager.AssetDetail memory params = IStandardManager(manager).assetDetails(deriveAsset);
            return params.isWhitelisted;
        } else if (managerType == ManagerType.PM2) {
            IPMRM2.CollateralParameters memory params = IPMRM2(manager).getCollateralParameters(deriveAsset);
            return params.isEnabled;
        } else {
            return false;
        }
    }
}
