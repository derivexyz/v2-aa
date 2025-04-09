// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface IStandardManager {
    enum AssetType {
        NotSet,
        Option,
        Perpetual,
        Base
    }

    struct AssetDetail {
        bool isWhitelisted;
        AssetType assetType;
        uint256 marketId;
    }

    function assetDetails(address asset) external view returns (AssetDetail memory);

    function settlePerpsWithIndex(uint256 subaccountId) external;
}
