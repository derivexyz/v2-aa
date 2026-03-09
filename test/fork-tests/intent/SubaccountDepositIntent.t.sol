// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase func-name-mixedcase
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";

import {SubaccountDepositIntent} from "src/intents/SubaccountDepositIntent.sol";
import {IntentExecutorBase} from "src/intents/IntentExecutorBase.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISubaccounts} from "../../../src/interfaces/ISubaccounts.sol";
import {IMatching} from "src/interfaces/derive/IMatching.sol";
import {IStandardManager} from "src/interfaces/derive/IStandardManager.sol";
import {ICash} from "src/interfaces/derive/ICash.sol";

/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */
contract FORK_LYRA_SubaccountDepositIntent is Test {
    // ERC20 token on derive mainnet
    address public immutable DAI = address(0xB56D58Ce246C31c4D3a3bFB354996FF28D081dB7);
    address public immutable USDC = address(0x6879287835A86F50f784313dBEd5E5cCC5bb8481);

    // Derive v2 asset on derive mainnet
    address public immutable DAIAsset = address(0x67bB0B7c87Df9C5C433ac7eCADfa7396A2927fcF);
    address public immutable cash = address(0x57B03E14d409ADC7fAb6CFc44b5886CAD2D5f02b);

    // Matching contract on derive mainnet
    IMatching public matching = IMatching(0xeB8d770ec18DB98Db922E9D83260A585b9F0DeAD);
    ISubaccounts public subaccounts = ISubaccounts(0xE7603DF191D699d8BD9891b821347dbAb889E5a5);

    uint256 public subaccountId;
    address public standardManager = address(0x28c9ddF9A3B29c2E6a561c1BC520954e5A33de5D);
    address public pm2 = address(0xc755DAe3fd295A687adf3e192387163f813F0598);

    // Any Smart wallet address
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
        depositIntent = new SubaccountDepositIntent(matching, cash);

        deal(DAI, user, 10 ether);
        deal(USDC, user, 1000 * 1e6);

        // user approves depositIntent to spend DAI
        vm.startPrank(user);

        // create a new subaccount to make sure balances are clean
        subaccountId = matching.createSubAccount(pm2);

        IERC20(DAI).approve(address(depositIntent), type(uint256).max);
        IERC20(USDC).approve(address(depositIntent), type(uint256).max);
        vm.stopPrank();

        // set executor as intent executor
        depositIntent.setIntentExecutor(executor, true);

        // set DAIAsset as allowed derive asset
        depositIntent.setManagerTypes(standardManager, SubaccountDepositIntent.ManagerType.Standard);
        depositIntent.setManagerTypes(pm2, SubaccountDepositIntent.ManagerType.PM2);
    }

    function test_DepositIntent() public onlyDeriveMainnet {
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

    function test_DepositIntent_Cash() public onlyDeriveMainnet {
        // // make sure we don't have pending PNL that might change cash balance on next call
        // IStandardManager(standardManager).settlePerpsWithIndex(subaccountId);
        // ICash(cash).accrueInterest();

        uint256 erc20BalanceBefore = IERC20(USDC).balanceOf(user);
        uint256 subaccountBalanceBefore = subaccounts.getBalance(subaccountId, cash, 0);

        uint256 amount = 1000 * 1e6;
        uint256 amountInCash = 1000 ether;

        vm.startPrank(executor);

        depositIntent.executeDepositIntent(user, subaccountId, cash, amount);
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(USDC).balanceOf(user);
        uint256 subaccountBalanceAfter = subaccounts.getBalance(subaccountId, cash, 0);

        assertEq(erc20BalanceAfter, erc20BalanceBefore - amount);
        assertEq(subaccountBalanceAfter, subaccountBalanceBefore + amountInCash);
    }

    function test_RevertIf_DepositToInvalidSubaccount() public onlyDeriveMainnet {
        uint256 invalidSubaccount = 100;

        vm.startPrank(executor);
        vm.expectRevert(SubaccountDepositIntent.SubaccountOwnerMismatch.selector);
        depositIntent.executeDepositIntent(user, invalidSubaccount, DAIAsset, 10 ether);
        vm.stopPrank();
    }

    function test_RevertIf_DeriveAssetNotAllowed() public onlyDeriveMainnet {
        address mockedDeriveAsset = address(0x123);

        vm.startPrank(executor);
        vm.expectRevert(SubaccountDepositIntent.DeriveAssetNotAllowed.selector);
        depositIntent.executeDepositIntent(user, subaccountId, mockedDeriveAsset, 10 ether);
        vm.stopPrank();
    }

    function test_RevertIf_AllowDeriveAsset_CallByExecutor() public onlyDeriveMainnet {
        // executor cannot call setAllowedDeriveAsset
        vm.startPrank(executor);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        depositIntent.setManagerTypes(standardManager, SubaccountDepositIntent.ManagerType.PM2);
        vm.stopPrank();
    }

    function test_RevertIf_TriggerByNonExecutor() public onlyDeriveMainnet {
        address nonExecutor = address(0x123);
        vm.startPrank(nonExecutor);
        vm.expectRevert(IntentExecutorBase.NotIntentExecutor.selector);
        depositIntent.executeDepositIntent(user, subaccountId, DAIAsset, 10 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}
