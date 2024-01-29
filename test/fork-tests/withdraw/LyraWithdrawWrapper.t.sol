// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "lib/forge-std/src/Test.sol";

import "src/withdraw/LyraWithdrawWrapper.sol";
import {USDC} from "src/mocks/USDC.sol";

/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */
contract FORK_LYRA_LyraWithdrawalTest is Test {
    address public immutable usdc = address(0x6879287835A86F50f784313dBEd5E5cCC5bb8481);

    address public immutable controller = address(0x4C9faD010D8be90Aba505c85eacc483dFf9b8Fa9);

    address public immutable connector = address(0x1281C1464449DB73bdAa30928BCC63Dc25D8D187);

    LyraWithdrawWrapper public wrapper;

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
        wrapper = new LyraWithdrawWrapper{value: 1 ether}(usdc, controller, 2000e18);

        _mintLyraUSDC(alice, 1000e6);
    }

    function test_fork_WithdrawViaWrapper() public onlyLyra {
        uint256 balanceBefore = IERC20(usdc).balanceOf(alice);
        uint256 amount = 100e6;

        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        wrapper.withdrawToL1(amount, alice, connector, 200_000);
        vm.stopPrank();

        uint256 balanceAfter = IERC20(usdc).balanceOf(alice);
        assertEq(balanceBefore - balanceAfter, amount);
    }

    function test_fork_RevertIf_AmountToLow() public onlyLyra {
        vm.startPrank(alice);
        IERC20(usdc).approve(address(wrapper), type(uint256).max);

        uint256 amount = 1e6;
        vm.expectRevert(bytes("withdraw amount < fee"));
        wrapper.withdrawToL1(amount, alice, connector, 200_000);

        vm.stopPrank();
    }

    function test_fork_CanRescueEth() public onlyLyra {
        vm.prank(alice);
        vm.expectRevert();
        wrapper.rescueEth();

        // can rescue from owner
        wrapper.rescueEth();
    }

    function test_fork_getFee() public onlyLyra {
        uint256 fee = wrapper.getFeeUSDC(connector, 200_000);
        assertGt(fee, 1e6);
        assertLt(fee, 300e6);
    }

    function _mintLyraUSDC(address account, uint256 amount) public {
        vm.prank(connector);
        IFiatController(controller).receiveInbound(abi.encode(account, amount));
    }

    receive() external payable {}
}
