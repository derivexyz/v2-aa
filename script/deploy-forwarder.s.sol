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
        // socket configs
        address socketVault;
        address socketConnector;
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
            config.socketVault,
            config.socketConnector
        );

        LyraSelfPayingForwarder selfPayingForwarder = new LyraSelfPayingForwarder(
            config.usdcLocal,
            config.usdcRemote,
            config.bridge,
            config.socketVault,
            config.socketConnector
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
                usdcLocal: 0x0f8BEaf58d4A237C88c9ed99D82003ab5c252c26, // our clone of USDC on op-goerli, with 18 decimals
                usdcRemote: 0xe80F2a02398BBf1ab2C9cc52caD1978159c215BD, // our testnet USDC //
                bridge: 0x0000000000000000000000000000000000000001, // no standard bridge on op-goerli
                // https://github.com/SocketDotTech/app-chain-token/blob/lyra-tesnet-to-prod/deployments/prod_lyra_addresses.json
                socketVault: 0x3d74c019E9caCBc968cF31B0810044a030B3E903,
                socketConnector: 0xfBf496B6DBda9d5e778e2563493BCb32F5A52B51
            });
        } else if (block.chainid == 1) {
            return DeploymentConfig({
                trustedForwarder: 0x3CACa7b48D0573D793d3b0279b5F0029180E83b6,
                usdcLocal: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mainnet USDC
                usdcRemote: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // OP USDC (Bridged)
                bridge: 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1, // OP bridge on mainnet todo: change to our bridge
                socketVault: 0x0000000000000000000000000000000000000001, // todo: add l1 address
                socketConnector: 0x0000000000000000000000000000000000000001 // todo: add l1 address
            });
        }

        revert("Need config set! Please set config in script/Deploy.s.sol");
    }
}
