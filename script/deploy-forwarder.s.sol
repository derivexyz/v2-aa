// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {LyraSelfPayingForwarder} from "src/gelato/LyraSelfPayingForwarder.sol";
import {LyraSponsoredForwarder} from "src/gelato/LyraSponsoredForwarder.sol";

contract Deploy is Script {
    struct DeploymentConfig {
        // Funding
        uint256 fundingAmount;
        // USDC configs
        address usdcLocal;
        // socket configs
        address socketVault;
    }
    // address socketConnector;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.log("Start deploying helper contracts! Deployer: ", vm.addr(deployerPrivateKey));

        DeploymentConfig memory config = _getConfig();

        // deploy LyraSponsoredForwarder
        LyraSponsoredForwarder sponsoredForwarder = new LyraSponsoredForwarder{value: config.fundingAmount}(
            config.usdcLocal,
            config.socketVault
        );

        LyraSelfPayingForwarder selfPayingForwarder = new LyraSelfPayingForwarder{value: config.fundingAmount}(
            config.usdcLocal,
            config.socketVault
        );

        console2.log("LyraSponsoredForwarder deployed at: ", address(sponsoredForwarder));

        console2.log("LyraSelfPayingForwarder deployed at: ", address(selfPayingForwarder));

        vm.stopBroadcast();
    }

    function _getConfig() internal view returns (DeploymentConfig memory) {
        if (block.chainid == 420) {
            // OP-Goerli
            return DeploymentConfig({
                fundingAmount: 0.15 ether,
                usdcLocal: 0x0f8BEaf58d4A237C88c9ed99D82003ab5c252c26, // our clone of USDC on op-goerli
                // Socket configs
                // See: https://github.com/SocketDotTech/app-chain-token/blob/lyra-tesnet-to-prod/deployments/prod_lyra_addresses.json
                socketVault: 0x3d74c019E9caCBc968cF31B0810044a030B3E903
            })
            // socketConnector: 0xfBf496B6DBda9d5e778e2563493BCb32F5A52B51
            ;
        } else if (block.chainid == 1) {
            // Mainnet
            return DeploymentConfig({
                fundingAmount: 0.15 ether,
                usdcLocal: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mainnet USDC
                socketVault: 0x6D303CEE7959f814042D31E0624fB88Ec6fbcC1d
            })
            // socketConnector: 0x0000000000000000000000000000000000000001 // todo: add l1 address
            ;
        }

        revert("No config for this network! Please set config in script/Deploy.s.sol");
    }
}
