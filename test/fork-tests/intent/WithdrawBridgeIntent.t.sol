// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
// solhint-disable func-name-mixedcase

pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";

import {WithdrawBridgeIntent} from "src/intents/WithdrawBridgeIntent.sol";
import {IntentExecutorBase} from "src/intents/IntentExecutorBase.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ISocketWithdrawWrapper} from "src/interfaces/derive/ISocketWithdrawWrapper.sol";
import {IOFTWithdrawWrapper} from "src/interfaces/derive/IOFTWithdrawWrapper.sol";
import {ILightAccount} from "src/interfaces/ILightAccount.sol";
/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */

contract FORK_LYRA_WithdrawBridgeIntent is Test {
    address public weETH = address(0x7B35b4c05a90Ea5f311AeC815BE4148b446a68a2);
    address public drv = address(0x2EE0fd70756EDC663AcC9676658A1497C247693A);

    // OFT withdraw wrapper
    IOFTWithdrawWrapper public oftBridge = IOFTWithdrawWrapper(0x9400cc156dad38a716047a67c897973A29A06710);

    // Socket withdraw wrapper
    ISocketWithdrawWrapper public socketBridge = ISocketWithdrawWrapper(0xea8E683D8C46ff05B871822a00461995F93df800);

    // Socket Parameters for testing
    address public weETHController = address(0xf58fF1Adc4d045e712a6D91e69d93B4092516659);
    address public weETHConnector = address(0x6Ee9b6ad1c97AdeeD071fd5f349cE65f91e43333);

    // Connector with min fee set
    address public weETHConnector2 = address(0xF6c475d2aB23d84e45AD3634C8956dCDe27315E0);

    // Mock scws
    address public scw = address(0x8dC92fB0e1C1F1Def6e424E50aaA66dbB124eb54);

    WithdrawBridgeIntent public bridgeIntent;

    address public executor = address(0xb0b);

    /**
     * Only run the test when running with --fork flag, and connected to Lyra mainnet
     */
    modifier onlyDeriveMainnet() {
        if (block.chainid != 957) return;
        _;
    }

    function setUp() public onlyDeriveMainnet {
        bridgeIntent = new WithdrawBridgeIntent(socketBridge, oftBridge);

        deal(weETH, scw, 10 ether);
        deal(drv, scw, 1000 ether);

        // set executor as intent executor
        bridgeIntent.setIntentExecutor(executor, true);
        // set bucket params
        bridgeIntent.setBucketParams(60, 10); // 10 withdrawals per minute

        // scw approves bridgeIntent to spend weETH
        vm.startPrank(scw);
        IERC20(weETH).approve(address(bridgeIntent), type(uint256).max);
        IERC20(drv).approve(address(bridgeIntent), type(uint256).max);

        vm.stopPrank();
    }

    function test_WithdrawIntent_weETH() public onlyDeriveMainnet {
        // test we can withdraw to SCW owner
        address owner = ILightAccount(scw).owner();

        uint256 erc20BalanceBefore = IERC20(weETH).balanceOf(scw);

        vm.startPrank(executor);
        bridgeIntent.executeWithdrawIntentSocket(
            scw, weETH, 1 ether, 0.1 ether, owner, weETHController, weETHConnector, 200000
        );
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(weETH).balanceOf(scw);
        assertEq(erc20BalanceAfter, erc20BalanceBefore - 1 ether);
    }

    function test_WithdrawIntent_NoMaxFee() public onlyDeriveMainnet {
        // test we can withdraw to SCW owner
        address owner = ILightAccount(scw).owner();

        uint256 erc20BalanceBefore = IERC20(weETH).balanceOf(scw);

        vm.startPrank(executor);
        bridgeIntent.executeWithdrawIntentSocket(
            scw, weETH, 1 ether, type(uint256).max, owner, weETHController, weETHConnector, 200000
        );
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(weETH).balanceOf(scw);
        assertEq(erc20BalanceAfter, erc20BalanceBefore - 1 ether);
    }

    function test_WithdrawIntent_DRV() public onlyDeriveMainnet {
        uint256 erc20BalanceBefore = IERC20(drv).balanceOf(scw);

        uint256 maxFee = 10e18; // 10 DRV
        address owner = ILightAccount(scw).owner();

        vm.startPrank(executor);
        bridgeIntent.executeWithdrawIntentLZ(scw, drv, 10 ether, maxFee, owner, 30184);
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(drv).balanceOf(scw);
        assertEq(erc20BalanceAfter, erc20BalanceBefore - 10 ether);
    }

    function test_RevertIf_TriggerByNonExecutor() public onlyDeriveMainnet {
        address nonExecutor = address(0x123);
        vm.startPrank(nonExecutor);
        vm.expectRevert(IntentExecutorBase.NotIntentExecutor.selector);

        bridgeIntent.executeWithdrawIntentSocket(
            scw, weETH, 1 ether, 0.1 ether, address(0), weETHController, weETHConnector, 200000
        );

        vm.expectRevert(IntentExecutorBase.NotIntentExecutor.selector);
        bridgeIntent.executeWithdrawIntentLZ(scw, drv, 10 ether, 10e18, address(0), 30184);
        vm.stopPrank();
    }

    function test_WithdrawStateUpdate() public onlyDeriveMainnet {
        address owner = ILightAccount(scw).owner();
        assertEq(bridgeIntent.isWithdrawLimitReached(), false);

        // set the withdraw limit to 1
        bridgeIntent.setBucketParams(60, 1);

        vm.prank(executor);
        _executeWithdrawWeETH(owner);

        assertEq(bridgeIntent.withdrawCount(), 1);
        assertEq(bridgeIntent.isWithdrawLimitReached(), true);

        // increase the withdraw limit, more withdrawals are allowed
        bridgeIntent.setBucketParams(60, 5);
        assertEq(bridgeIntent.isWithdrawLimitReached(), false);

        vm.prank(executor);
        _executeWithdrawWeETH(owner);

        assertEq(bridgeIntent.withdrawCount(), 2);
    }

    function test_RevertIf_LimitNotSetByOwner() public onlyDeriveMainnet {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vm.prank(executor);
        bridgeIntent.setBucketParams(60, 100);
    }

    function test_RevertIf_WithdrawLimitReached() public onlyDeriveMainnet {
        address owner = ILightAccount(scw).owner();
        // set the withdraw limit to 1
        bridgeIntent.setBucketParams(60, 1);

        vm.startPrank(executor);
        _executeWithdrawWeETH(owner);

        // expect revert for the second withdraw
        vm.expectRevert(WithdrawBridgeIntent.WithdrawLimitReached.selector);
        _executeWithdrawDRV(owner);

        // after 1 minute, the withdraw can go through
        vm.warp(block.timestamp + 60);
        _executeWithdrawWeETH(owner);

        vm.stopPrank();
    }

    function test_WithdrawLimit_Update() public onlyDeriveMainnet {
        address owner = ILightAccount(scw).owner();
        // set the withdraw limit to 2 per minute
        bridgeIntent.setBucketParams(60, 2);

        vm.startPrank(executor);

        // withdraw 2 times
        _executeWithdrawDRV(owner);
        _executeWithdrawDRV(owner);

        // expect revert for the third withdraw
        vm.expectRevert(WithdrawBridgeIntent.WithdrawLimitReached.selector);
        _executeWithdrawDRV(owner);
        vm.stopPrank();

        // after 30 seconds, the withdraw limit is updated to 3 times every 120 seconds
        // the timer will not reset
        vm.warp(block.timestamp + 30);
        bridgeIntent.setBucketParams(120, 3);

        vm.startPrank(executor);
        // 1 more withdraw is allowed
        _executeWithdrawDRV(owner);

        // revert for the fourth withdraw
        vm.expectRevert(WithdrawBridgeIntent.WithdrawLimitReached.selector);
        _executeWithdrawDRV(owner);

        // wait another 30 seconds, the limit is still there
        vm.warp(block.timestamp + 30);
        vm.expectRevert(WithdrawBridgeIntent.WithdrawLimitReached.selector);
        _executeWithdrawDRV(owner);
        assertEq(bridgeIntent.withdrawCount(), 3);

        // wait another 60 seconds, the limit is reset
        vm.warp(block.timestamp + 60);
        // 1 more withdraw is allowed
        _executeWithdrawDRV(owner);
        assertEq(bridgeIntent.withdrawCount(), 1);

        vm.stopPrank();
    }

    function test_RevertIf_FeeTooHigh() public onlyDeriveMainnet {
        address owner = ILightAccount(scw).owner();
        vm.startPrank(executor);

        // DRV bridge
        uint256 fee = oftBridge.getFeeInToken(drv, 10 ether, 30184);

        vm.expectRevert(WithdrawBridgeIntent.FeeTooHigh.selector);
        bridgeIntent.executeWithdrawIntentLZ(scw, drv, 10 ether, fee - 1, owner, 30184);

        // weETH bridge
        fee = socketBridge.getFeeInToken(weETH, weETHController, weETHConnector2, 200000);
        vm.expectRevert(WithdrawBridgeIntent.FeeTooHigh.selector);
        bridgeIntent.executeWithdrawIntentSocket(
            scw, weETH, 1 ether, fee - 1, owner, weETHController, weETHConnector2, 200000
        );

        vm.stopPrank();
    }

    /// @dev wrapped function used to simplify the limit tests
    function _executeWithdrawDRV(address owner) internal {
        bridgeIntent.executeWithdrawIntentLZ(scw, drv, 10 ether, 10e18, owner, 30184);
    }

    /// @dev wrapped function used to simplify the limit tests
    function _executeWithdrawWeETH(address owner) internal {
        bridgeIntent.executeWithdrawIntentSocket(
            scw, weETH, 1 ether, 0.1 ether, owner, weETHController, weETHConnector, 200000
        );
    }

    receive() external payable {}
}
