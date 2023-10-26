// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {LyraSelfPayingForwarder} from "src/gelato/LyraSelfPayingForwarder.sol";
import {LyraSponsoredForwarder} from "src/gelato/LyraSponsoredForwarder.sol";

contract Deploy is Script {
    function setUp() public {}

    struct DeploymentConfig {
        address trustedForwarder;
        address usdcLocal;
        address usdcRemote;
        address bridge;
        address socketVault;
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Start deploying core contracts! deployer: ", deployer);

        DeploymentConfig memory config = _getConfig();

        // deploy LyraSponsoredForwarder
        LyraSponsoredForwarder sponsoredForwarder = new LyraSponsoredForwarder(
            config.trustedForwarder,
            config.usdcLocal,
            config.usdcRemote,
            config.bridge
            // config.socketVault
        );

        LyraSelfPayingForwarder selfPayingForwarder = new LyraSelfPayingForwarder(
            config.usdcLocal,
            config.usdcRemote,
            config.bridge
            // config.socketVault
        );

        console2.log("LyraSponsoredForwarder deployed at: ", address(sponsoredForwarder));

        console2.log("LyraSelfPayingForwarder deployed at: ", address(selfPayingForwarder));

        vm.stopBroadcast();
    }

    function _getConfig() internal view returns (DeploymentConfig memory) {
        uint256 opgoerli = 420;

        if (block.chainid == opgoerli) {
            return DeploymentConfig({
                trustedForwarder: 0xd8253782c45a12053594b9deB72d8e8aB2Fca54c,
                usdcLocal: 0xe05606174bac4A6364B31bd0eCA4bf4dD368f8C6, // official USDC op goerli
                usdcRemote: 0x0000000000000000000000000000000000000000, //
                bridge: 0x0000000000000000000000000000000000000000,
                // no standard bridge on goerli
                socketVault: 0x0000000000000000000000000000000000000000 // todo: add socket vault
            });
        } else if (block.chainid == 1) {
            return DeploymentConfig({
                trustedForwarder: 0x3CACa7b48D0573D793d3b0279b5F0029180E83b6,
                usdcLocal: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mainnet USDC
                usdcRemote: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // OP USDC (Bridged)
                bridge: 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1, // OP bridge on mainnet
                socketVault: 0x0000000000000000000000000000000000000000
            });
        }

        revert("Need config set! Please set config in script/Deploy.s.sol");
    }
}
