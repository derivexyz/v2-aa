// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
// solhint-disable func-name-mixedcase

pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";

import {StakeDRVIntent} from "src/intents/StakeDRVIntent.sol";
import {IntentExecutorBase} from "src/intents/IntentExecutorBase.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IStakedDRV} from "src/interfaces/derive/IStakedDRV.sol";
import {ILightAccount} from "src/interfaces/ILightAccount.sol";

/**
 * forge test --fork-url https://rpc.lyra.finance -vvv
 */
contract FORK_LYRA_StakeDRVIntent is Test {
    address public drv = address(0x2EE0fd70756EDC663AcC9676658A1497C247693A);
    address public stakedDRV = address(0x7499d654422023a407d92e1D83D387d81BC68De1);

    // Mock scws
    address public scw = address(0xa0a);

    StakeDRVIntent public stakeIntent;
    address public executor = address(0xb0b);

    /**
     * Only run the test when running with --fork flag, and connected to Lyra mainnet
     */
    modifier onlyDeriveMainnet() {
        if (block.chainid != 957) return;
        _;
    }

    function setUp() public onlyDeriveMainnet {
        stakeIntent = new StakeDRVIntent(drv, stakedDRV);

        deal(drv, scw, 1000 ether);

        // set executor as intent executor
        stakeIntent.setIntentExecutor(executor, true);

        // scw approves stakeIntent to spend drv
        vm.prank(scw);
        IERC20(drv).approve(address(stakeIntent), type(uint256).max);
    }

    function test_StakeIntent_DRV() public onlyDeriveMainnet {
        uint256 erc20BalanceBefore = IERC20(drv).balanceOf(scw);
        uint256 stakedDRVBalanceBefore = IERC20(stakedDRV).balanceOf(scw);

        vm.startPrank(executor);
        stakeIntent.executeStakeDRVIntent(scw, 1 ether);
        vm.stopPrank();

        uint256 erc20BalanceAfter = IERC20(drv).balanceOf(scw);
        assertEq(erc20BalanceAfter, erc20BalanceBefore - 1 ether);

        uint256 stakedDRVBalanceAfter = IERC20(stakedDRV).balanceOf(scw);
        assertEq(stakedDRVBalanceAfter, stakedDRVBalanceBefore + 1 ether);
    }

    function test_RevertIf_TriggerByNonExecutor() public onlyDeriveMainnet {
        address nonExecutor = address(0x123);
        vm.startPrank(nonExecutor);
        vm.expectRevert(IntentExecutorBase.NotIntentExecutor.selector);
        stakeIntent.executeStakeDRVIntent(scw, 1 ether);
        vm.stopPrank();
    }

    function test_RescueToken() public onlyDeriveMainnet {
        deal(address(drv), address(stakeIntent), 1000 ether);

        uint256 balanceBefore = IERC20(drv).balanceOf(address(this));
        stakeIntent.rescueToken(drv);

        uint256 balanceAfter = IERC20(drv).balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore + 1000 ether);
    }

    receive() external payable {}
}
