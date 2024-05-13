// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "lib/forge-std/src/Test.sol";

import {LyraDepositWrapper} from "src/helpers/LyraDepositWrapper.sol";
import {IERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import "../../../src/helpers/LyraWstETHZapper.sol";

/**
 * forge test --fork-url https://mainnet.infura.io/v3/${INFURA_PROJECT_ID} -vvv
 */
contract FORK_MAINNET_LyrWstETHZapper is Test {
    address public weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public wstETH = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    address public stETH = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    address public wstethVault = address(0xeBB5D642aA8ccDeE98373D6aC3ee0602b63824b3);
    address public wstethConnector = address(0xdCcFb24f983586144c085426dbfa3414045E19a3);

    LyraWstETHZapper public zapper;

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
        zapper = new LyraWstETHZapper(weth, wstETH);

        vm.deal(alice, 100 ether);
    }

    function test_deposit_WETH() public onlyMainnet {
        vm.startPrank(alice);
        IWETH(weth).deposit{value: 20 ether}();
        IERC20(weth).approve(address(zapper), type(uint256).max);

        uint256 socketFee = 0.03 ether;

        zapper.zapWETH{value: socketFee}(20 ether, wstethVault, true, 200_000, wstethConnector);
        vm.stopPrank();
    }

    function test_deposit_ETH() public onlyMainnet {
        vm.startPrank(alice);
        zapper.zapETH{value: 20 ether}(wstethVault, true, 200_000, wstethConnector);
        vm.stopPrank();
    }

    function test_deposit_stETH() public onlyMainnet {
        vm.startPrank(alice);

        IStETH(stETH).submit{value: 15 ether}(address(alice));
        IStETH(stETH).approve(address(zapper), 15 ether);

        zapper.zapStETH{value: 0.03 ether}(15 ether, wstethVault, true, 200_000, wstethConnector);
        vm.stopPrank();
    }

    receive() external payable {}
}
