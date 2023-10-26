// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console2.sol";

import "src/gelato/LyraSelfPayingForwarder.sol";
import {USDC} from "src/mocks/USDC.sol";

contract FORK_SelfPayingForwarderTest is Test {
    address public immutable gelato = address(0x3CACa7b48D0573D793d3b0279b5F0029180E83b6);

    address public immutable gelatoRelayer = address(0xb539068872230f20456CF38EC52EF2f91AF4AE49);

    address public immutable usdcMainnet = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // all transactions go from gelato => gelatoRelayer -> forwarder

    LyraSelfPayingForwarder public forwarder;

    uint256 public alicePk = 0xbabebabe;
    address public alice = vm.addr(alicePk);

    function setUp() public {
        if (block.chainid != 1) revert("Please run against mainnet fork");

        // deploy test contract
        forwarder = new LyraSelfPayingForwarder(
          0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mainnet USDC
          0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // OP USDC (Bridged) 
          0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1, // OP bridge on mainnet
          0x0000000000000000000000000000000000000000
        );

        _mintMainnetUSDC(alice, 1e6 * 1e6);
    }

    function test_fork_SelfPayingForwarder() public {
        assertFalse(address(forwarder) == address(0));
    }

    function test_fork_depositFromEOA() public {
        // alice sign transfer with auth

        // call forwarder
    }

    function _mintMainnetUSDC(address account, uint256 amount) public {
        vm.prank(0xE982615d461DD5cD06575BbeA87624fda4e3de17); // masterMinter for USDC
        USDC(usdcMainnet).configureMinter(address(this), 5000e18);

        // mint from address(this)
        USDC(usdcMainnet).mint(account, amount);
    }

    function _sendTxAsGelatoRelayer() public {
        vm.startPrank(gelatoRelayer);
        // attach sender info at end of tx
        vm.stopPrank();
    }
}
