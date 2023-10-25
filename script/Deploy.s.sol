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
            config.bridge,
            config.socketVault
        );

        console2.log("LyraSponsoredForwarder deployed at: ", address(sponsoredForwarder));

        vm.stopBroadcast();
    }

    function _getConfig() internal returns (DeploymentConfig memory) {
        uint256 opgoerli = 420;

        if (block.chainid == opgoerli) {
            return DeploymentConfig({
                trustedForwarder: 0xd8253782c45a12053594b9deB72d8e8aB2Fca54c,
                usdcLocal: 0xe05606174bac4A6364B31bd0eCA4bf4dD368f8C6, // official USDC op goerli
                usdcRemote: 0x0000000000000000000000000000000000000000, //
                bridge: 0x0000000000000000000000000000000000000000, // not testing l1 standard bridge on goerli
                socketVault: 0x0000000000000000000000000000000000000000 // todo: add socket vault
            });
        }

        revert("Need config set! Please set config in script/Deploy.s.sol");
    }
}
