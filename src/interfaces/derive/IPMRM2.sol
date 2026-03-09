// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

interface IPMRM2 {
    function collateralSpotFeeds(address collateral) external view returns (address);
}
