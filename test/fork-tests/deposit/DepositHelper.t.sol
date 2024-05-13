// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "lib/forge-std/src/Test.sol";

import {LyraDepositWrapper} from "src/helpers/LyraDepositWrapper.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

/**
 * forge test --fork-url https://mainnet.infura.io/v3/b3801473275f4a0a846ea7fe5a629349 -vvv ${INFURA_PROJECT_ID} -vvv
 */
contract FORK_MAINNET_LyraDepositWrapper is Test {
    address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address public wethVault = address(0xD4efe33C66B8CdE33B8896a2126E41e5dB571b7e);
    address public wethConnector = address(0xCf814e58f1649F94d37E51f730D6bF72409fA09c);

    LyraDepositWrapper public wrapper;

    uint256 public alicePk = 0xbabebabe;
    address public alice = vm.addr(alicePk);

    /**
     * Only run the test when running with --fork flag, and connected to Lyra mainnet
     */
    modifier onlyMainnet() {
        if (block.chainid != 1) return;
        _;
    }

    function setUp() public onlyMainnet {
        wrapper = new LyraDepositWrapper(weth);

        vm.deal(alice, 100 ether);
    }

    function test_deposit_ETH() public onlyMainnet {
        vm.prank(alice);

        wrapper.depositETHToLyra{value: 20 ether}(wethVault, true, 200_000, wethConnector);
    }

    function test_deposit_WETH() public onlyMainnet {
        vm.startPrank(alice);
        IWETH(weth).deposit{value: 20 ether}();
        IERC20(weth).approve(address(wrapper), type(uint256).max);

        uint256 socketFee = 0.03 ether;

        wrapper.depositToLyra{value: socketFee}(weth, wethVault, true, 20 ether, 200_000, wethConnector);
        vm.stopPrank();
    }

    receive() external payable {}
}
