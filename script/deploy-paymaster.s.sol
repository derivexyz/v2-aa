// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {VerifyingPaymasterFix, IEntryPoint} from "src/erc4337/VerifyingPaymasterFix.sol";

contract DeployPaymaster is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        VerifyingPaymasterFix paymaster =
            new VerifyingPaymasterFix(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), vm.addr(deployerPrivateKey));
        console2.log("VerifyingPaymasterFix deployed at: ", address(paymaster));
        vm.stopBroadcast();
    }
}
