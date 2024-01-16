// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "lib/forge-std/src/Test.sol";

import "src/withdraw/LyraWithdrawWrapperV2.sol";
import {USDC} from "src/mocks/USDC.sol";

/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */
contract FORK_LyraWithdrawalV2Test is Test {
    address public usdc = address(0x6879287835A86F50f784313dBEd5E5cCC5bb8481);

    // withdraw as official USDC
    address public usdcController = address(0x4C9faD010D8be90Aba505c85eacc483dFf9b8Fa9);
    address public usdc_Mainnet_Connector = address(0x1281C1464449DB73bdAa30928BCC63Dc25D8D187);
    address public usdc_Arbi_Connector = address(0xBdE9e687F3A23Ebbc972c58D510dfc1f58Fb35EF); // as native USDC

    // wbtc asset
    address public wBTC = address(0x9b80ab732a6F1030326Af0014f106E12C4Db18EC);
    address public wBTCController = address(0xaf33761742beF3B7d0D0726671660CCF260fc5c3);
    address public wBTC_OP_Connector = address(0xC50Abb760555f73CCCa8C4D4ff56D4Bd4AAAAfC9);

    LyraWithdrawWrapperV2 public wrapper;

    uint256 public alicePk = 0xbabebabe;
    address public alice = vm.addr(alicePk);

    /**
     * Only run the test when running with --fork flag, and connected to Lyra mainnet
     */
    modifier onlyLyra() {
        if (block.chainid != 957) return;
        _;
    }

    function setUp() public onlyLyra {
        wrapper = new LyraWithdrawWrapperV2{value: 1 ether}();

        _mintLyraUSDC(alice, 1000e6);

        wrapper.setStaticRate(usdc, 2500 * 1e18 * 1e6); // 2500 USDC = 1 ETH

        wrapper.setStaticRate(wBTC, 0.06 * 1e18 * 1e8); // 0.06 WBTC = 1 ETH
    }

    function test_fork_Withdraw_USDC() public onlyLyra {
        uint256 balanceBefore = IERC20(usdc).balanceOf(alice);
        uint256 amount = 100e6;

        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        wrapper.withdrawToChain(usdc, amount, alice, usdcController, usdc_Mainnet_Connector, 200_000);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(usdc).balanceOf(alice);
        assertEq(balanceBefore - balanceAfter, amount);
    }

    function test_fork_Withdraw_BridgeUSDC() public onlyLyra {
        uint256 balanceBefore = IERC20(usdc).balanceOf(alice);
        uint256 amount = 100e6;

        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        wrapper.withdrawToChain(usdc, amount, alice, usdcController, usdc_Arbi_Connector, 200_000);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(usdc).balanceOf(alice);
        assertEq(balanceBefore - balanceAfter, amount);
    }

    function test_fork_RevertIf_tokenMismatch() public onlyLyra {
        // _mintLyraUSDC(address(wrapper), 1000e6);
        uint256 amount = 100e6;

        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        // send USDC but request withdraw WBTC
        vm.expectRevert();
        wrapper.withdrawToChain(usdc, amount, alice, wBTCController, wBTC_OP_Connector, 200_000);
        vm.stopPrank();
    }

    function test_fork_Withdraw_WBTC() public onlyLyra {
        uint256 amount = 1e8;

        _mintLyraWBTC(alice, amount);

        uint256 feeInWBTC = wrapper.getFeeInToken(wBTC, wBTCController, wBTC_OP_Connector, 200_000);

        uint256 balanceBefore = IERC20(wBTC).balanceOf(alice);

        vm.startPrank(alice);
        IERC20(wBTC).approve(address(wrapper), type(uint256).max);

        wrapper.withdrawToChain(wBTC, amount, alice, wBTCController, wBTC_OP_Connector, 200_000);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(wBTC).balanceOf(alice);
        assertEq(balanceBefore - balanceAfter, amount);

        // fee is paid to owner
        assertEq(IERC20(wBTC).balanceOf(address(this)), feeInWBTC);
    }

    function test_fork_RevertIf_AmountToLow() public onlyLyra {
        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        uint256 amount = 1e6;
        vm.expectRevert(bytes("withdraw amount < fee"));
        wrapper.withdrawToChain(usdc, amount, alice, usdcController, usdc_Arbi_Connector, 200_000);

        vm.stopPrank();
    }

    function test_fork_getFee() public onlyLyra {
        uint256 fee = wrapper.getFeeInToken(usdc, usdcController, usdc_Mainnet_Connector, 200_000);
        assertGt(fee, 1e6);
        assertLt(fee, 300e6);

        fee = wrapper.getFeeInToken(usdc, usdcController, usdc_Arbi_Connector, 200_000);
        assertLt(fee, 10e6);
    }

    function _mintLyraUSDC(address account, uint256 amount) public {
        vm.prank(usdc_Mainnet_Connector);
        IFiatController(usdcController).receiveInbound(abi.encode(account, amount));
    }

    function _mintLyraWBTC(address account, uint256 amount) public {
        vm.prank(wBTC_OP_Connector);
        IFiatController(wBTCController).receiveInbound(abi.encode(account, amount));
    }

    receive() external payable {}
}
