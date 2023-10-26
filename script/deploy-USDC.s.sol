// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {USDC} from "../src/mocks/USDC.sol";

contract DeployUSDC is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Start deploying core contracts! deployer: ", deployer);

        USDC usdc = new USDC();

        console2.log("USDC deployed at: ", address(usdc));

        vm.stopBroadcast();
    }
}
