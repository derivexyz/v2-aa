// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IPMRM2 {
    // Defined once per collateral
    struct CollateralParameters {
        bool isEnabled;
        bool isRiskCancelling;
        /// @dev % value of collateral to subtract from MM. Must be <= 1
        uint256 MMHaircut;
        /// @dev % value of collateral to subtract from IM. Added on top of MMHaircut. Must be <= 1
        uint256 IMHaircut;
    }

    function getCollateralParameters(address collateral) external view returns (CollateralParameters memory);
}
