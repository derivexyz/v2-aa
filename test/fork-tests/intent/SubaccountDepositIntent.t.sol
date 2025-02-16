// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";

import {SubaccountDepositIntent} from "src/intents/SubaccountDepositIntent.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISubaccounts} from "./interfaces/ISubaccounts.sol";
/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */

contract FORK_DERIVE_MAINNET_SubaccountDepositIntent is Test {
    // ERC20 token on derive mainnet
    address public rsETH = address(0xc47e2E800a9184cFbD274AC1eeCcCDF942715dB7);

    // Derive v2 asset on derive mainnet
    address public rsETHAsset = address(0x35fdB6e79c05809ba6Dc3B2EF5FF7D0BB5D75020);

    // SubaccountDepositIntent on derive mainnet
    ISubaccounts public subaccounts = ISubaccounts(0xE7603DF191D699d8BD9891b821347dbAb889E5a5);

    // Mock light account address: owner of Subaccount 1
    uint256 public subaccountId = 1;
    address public user = address(0x8dC92fB0e1C1F1Def6e424E50aaA66dbB124eb54);

    SubaccountDepositIntent public depositIntent;

    address public executor = address(0xb0b);

    /**
     * Only run the test when running with --fork flag, and connected to Lyra mainnet
     */
    modifier onlyDeriveMainnet() {
        if (block.chainid != 957) return;
        _;
    }

    function setUp() public onlyDeriveMainnet {
        depositIntent = new SubaccountDepositIntent(subaccounts);

        deal(rsETH, user, 10 ether);

        // user approves depositIntent to spend rsETH
        vm.prank(user);
        IERC20(rsETH).approve(address(depositIntent), type(uint256).max);

        // set executor as intent executor
        depositIntent.setIntentExecutor(executor, true);
    }

    function testDepositIntent() public onlyDeriveMainnet {
        uint256 erc20BalanceBefore = IERC20(rsETH).balanceOf(user);
        uint256 subaccountBalanceBefore = subaccounts.getBalance(subaccountId, rsETHAsset, 0);

        vm.startPrank(executor);
        depositIntent.executeDepositIntent(user, subaccountId, rsETHAsset, 10 ether);
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(rsETH).balanceOf(user);
        uint256 subaccountBalanceAfter = subaccounts.getBalance(subaccountId, rsETHAsset, 0);

        assertEq(erc20BalanceAfter, erc20BalanceBefore - 10 ether);
        assertEq(subaccountBalanceAfter, subaccountBalanceBefore + 10 ether);
    }

    function testCannotDepositToInvalidSubaccount() public onlyDeriveMainnet {
        uint256 invalidSubaccount = 100;

        vm.startPrank(executor);
        vm.expectRevert(SubaccountDepositIntent.SubaccountOwnerMismatch.selector);
        depositIntent.executeDepositIntent(user, invalidSubaccount, rsETHAsset, 10 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}
