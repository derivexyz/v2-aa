// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";

import {SubaccountDepositIntent} from "src/intents/SubaccountDepositIntent.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISubaccounts} from "./interfaces/ISubaccounts.sol";
import {IMatching} from "src/interfaces/derive/IMatching.sol";

/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */
contract FORK_LYRA_SubaccountDepositIntent is Test {
    // ERC20 token on derive mainnet
    address public immutable DAI = address(0xB56D58Ce246C31c4D3a3bFB354996FF28D081dB7);

    // Derive v2 asset on derive mainnet
    address public immutable DAIAsset = address(0x67bB0B7c87Df9C5C433ac7eCADfa7396A2927fcF);

    // Matching contract on derive mainnet
    IMatching public matching = IMatching(0xeB8d770ec18DB98Db922E9D83260A585b9F0DeAD);
    ISubaccounts public subaccounts = ISubaccounts(0xE7603DF191D699d8BD9891b821347dbAb889E5a5);

    // Mock light account address: owner of Subaccount 1
    uint256 public subaccountId = 15;
    address public user = address(0x03CdE1E0bc6C1e096505253b310Cf454b0b462FB);

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
        depositIntent = new SubaccountDepositIntent(matching);

        deal(DAI, user, 10 ether);

        // user approves depositIntent to spend DAI
        vm.prank(user);
        IERC20(DAI).approve(address(depositIntent), type(uint256).max);

        // set executor as intent executor
        depositIntent.setIntentExecutor(executor, true);
    }

    function testDepositIntent() public onlyDeriveMainnet {
        uint256 erc20BalanceBefore = IERC20(DAI).balanceOf(user);
        uint256 subaccountBalanceBefore = subaccounts.getBalance(subaccountId, DAIAsset, 0);

        vm.startPrank(executor);
        depositIntent.executeDepositIntent(user, subaccountId, DAIAsset, 10 ether);
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(DAI).balanceOf(user);
        uint256 subaccountBalanceAfter = subaccounts.getBalance(subaccountId, DAIAsset, 0);

        assertEq(erc20BalanceAfter, erc20BalanceBefore - 10 ether);
        assertEq(subaccountBalanceAfter, subaccountBalanceBefore + 10 ether);
    }

    function testCannotDepositToInvalidSubaccount() public onlyDeriveMainnet {
        uint256 invalidSubaccount = 100;

        vm.startPrank(executor);
        vm.expectRevert(SubaccountDepositIntent.SubaccountOwnerMismatch.selector);
        depositIntent.executeDepositIntent(user, invalidSubaccount, DAIAsset, 10 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}
