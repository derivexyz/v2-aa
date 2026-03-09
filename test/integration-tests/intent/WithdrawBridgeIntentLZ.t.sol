// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
// solhint-disable func-name-mixedcase
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";

import {WithdrawBridgeIntent} from "src/intents/WithdrawBridgeIntent.sol";
import {IntentExecutorBase} from "src/intents/IntentExecutorBase.sol";
import {LyraOFTWithdrawWrapperV2} from "src/withdraw/OFTWithdrawWrapperV2.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ISocketWithdrawWrapper} from "src/interfaces/derive/ISocketWithdrawWrapper.sol";
import {IOFTWithdrawWrapper} from "src/interfaces/derive/IOFTWithdrawWrapper.sol";
import {ILightAccount} from "src/interfaces/ILightAccount.sol";

/**
 * @title Integration tests for WithdrawBridgeIntent LayerZero functionality
 * @notice Tests the executeWithdrawIntentLZ function with mock OFT Wrapper and approved destinations
 */
contract WithdrawBridgeIntentLZTest is Test {
    uint32 internal constant DEST_EID = 30184; // Example destination EID (EVM)
    uint32 internal constant NON_EVM_DEST_EID = 30168; // Example non-EVM destination EID (e.g., Solana)

    // Contracts
    WithdrawBridgeIntent public bridgeIntent;
    MockOFTWithdrawWrapper public oftWithdrawWrapper;
    MockSocketWithdrawWrapper public mockSocketWrapper;

    // Mock ERC20 token
    MockERC20 public token;

    // Mock Light Account
    MockLightAccount public scw;

    // Test addresses
    address public executor = makeAddr("executor");
    address public owner = makeAddr("owner");
    address public alternativeRecipient = makeAddr("alternativeRecipient");

    uint256 public initialBalance = 100 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        // Deploy mock token
        token = new MockERC20("MockToken", "MTK");

        // Deploy mock wrappers
        oftWithdrawWrapper = new MockOFTWithdrawWrapper();
        mockSocketWrapper = new MockSocketWithdrawWrapper();

        // Deploy SCW mock
        scw = new MockLightAccount(owner);

        // Deploy WithdrawBridgeIntent
        bridgeIntent = new WithdrawBridgeIntent(
            ISocketWithdrawWrapper(address(mockSocketWrapper)),
            IOFTWithdrawWrapper(address(oftWithdrawWrapper))
        );

        // Setup executor
        bridgeIntent.setIntentExecutor(executor, true);
        bridgeIntent.setBucketParams(60, 10);  // 10 withdrawals per minute

        // Mark DEST_EID as EVM chain so owner is a valid recipient
        bridgeIntent.setEvmEID(DEST_EID, true);

        // Mint tokens to SCW
        token.mint(address(scw), initialBalance);

        // SCW approves bridgeIntent
        vm.prank(address(scw));
        token.approve(address(bridgeIntent), type(uint256).max);
    }

    // ============ Basic Withdraw Tests ============

    function test_WithdrawIntentLZ_ToOwner() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        uint256 balanceBefore = token.balanceOf(address(scw));

        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            type(uint256).max,  // No max fee check
            recipientBytes32,
            DEST_EID
        );

        // Verify tokens were transferred from SCW
        uint256 balanceAfter = token.balanceOf(address(scw));
        assertEq(balanceBefore - balanceAfter, amount);

        // Verify wrapper received the tokens and correct params
        assertEq(oftWithdrawWrapper.lastToken(), address(token));
        assertEq(oftWithdrawWrapper.lastAmount(), amount);
        assertEq(oftWithdrawWrapper.lastRecipient(), recipientBytes32);
        assertEq(oftWithdrawWrapper.lastDestEID(), DEST_EID);
    }

    function test_WithdrawIntentLZ_ToApprovedDestination() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(alternativeRecipient);

        // SCW adds alternative recipient as approved destination
        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(recipientBytes32);

        assertTrue(bridgeIntent.isApprovedDestination(address(scw), recipientBytes32, true));

        uint256 balanceBefore = token.balanceOf(address(scw));

        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );

        // Verify tokens were transferred
        uint256 balanceAfter = token.balanceOf(address(scw));
        assertEq(balanceBefore - balanceAfter, amount);

        // Verify correct recipient was passed
        assertEq(oftWithdrawWrapper.lastRecipient(), recipientBytes32);
    }

    function test_RevertIf_WithdrawIntentLZ_UnapprovedDestination() public {
        uint256 amount = 10 ether;
        bytes32 unapprovedRecipient = _addressToBytes32(alternativeRecipient);

        // alternativeRecipient is NOT approved
        assertFalse(bridgeIntent.isApprovedDestination(address(scw), unapprovedRecipient, true));

        vm.prank(executor);
        vm.expectRevert(WithdrawBridgeIntent.InvalidRecipient.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            type(uint256).max,
            unapprovedRecipient,
            DEST_EID
        );
    }

    // ============ Approved Destination Management Tests ============

    function test_AddApprovedDestination() public {
        bytes32 destination = _addressToBytes32(alternativeRecipient);

        bytes32[] memory destinationsBefore = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinationsBefore.length, 0);

        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(destination);

        bytes32[] memory destinationsAfter = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinationsAfter.length, 1);
        assertEq(destinationsAfter[0], destination);
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), destination, true));
    }

    function test_RemoveApprovedDestination() public {
        bytes32 destination = _addressToBytes32(alternativeRecipient);

        // Add first
        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(destination);
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), destination, true));

        // Remove
        vm.prank(address(scw));
        bridgeIntent.removeApprovedDestination(destination);

        bytes32[] memory destinations = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinations.length, 0);
        assertFalse(bridgeIntent.isApprovedDestination(address(scw), destination, false));
    }

    function test_WithdrawIntentLZ_AfterRemovingDestination() public {
        bytes32 recipientBytes32 = _addressToBytes32(alternativeRecipient);

        // Add then remove
        vm.startPrank(address(scw));
        bridgeIntent.addApprovedDestination(recipientBytes32);
        bridgeIntent.removeApprovedDestination(recipientBytes32);
        vm.stopPrank();

        // Should revert now
        vm.prank(executor);
        vm.expectRevert(WithdrawBridgeIntent.InvalidRecipient.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );
    }

    function test_OwnerAlwaysApproved() public {
        bytes32 ownerBytes32 = _addressToBytes32(owner);

        // Owner should always be approved without explicit addition
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), ownerBytes32, true));

        // Owner is not in the array (because it's always implicitly approved)
        bytes32[] memory destinations = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinations.length, 0);

        // Owner should still be approved
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), ownerBytes32, true));
    }

    function test_MultipleApprovedDestinations() public {
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        address recipient3 = makeAddr("recipient3");

        bytes32 dest1 = _addressToBytes32(recipient1);
        bytes32 dest2 = _addressToBytes32(recipient2);
        bytes32 dest3 = _addressToBytes32(recipient3);

        vm.startPrank(address(scw));
        bridgeIntent.addApprovedDestination(dest1);
        bridgeIntent.addApprovedDestination(dest2);
        bridgeIntent.addApprovedDestination(dest3);
        vm.stopPrank();

        assertTrue(bridgeIntent.isApprovedDestination(address(scw), dest1, true));
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), dest2, true));
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), dest3, true));

        // Remove one
        vm.prank(address(scw));
        bridgeIntent.removeApprovedDestination(dest2);

        assertTrue(bridgeIntent.isApprovedDestination(address(scw), dest1, true));
        assertFalse(bridgeIntent.isApprovedDestination(address(scw), dest2, true));
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), dest3, true));
    }

    // ============ Fee Tests ============

    function test_RevertIf_FeeTooHigh() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        // Set mock fee
        oftWithdrawWrapper.setMockFee(1 ether);

        // Set max fee below actual fee
        vm.prank(executor);
        vm.expectRevert(WithdrawBridgeIntent.FeeTooHigh.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            0.5 ether,  // Max fee below actual
            recipientBytes32,
            DEST_EID
        );
    }

    function test_WithdrawIntentLZ_WithMaxFeeCheck() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        // Set mock fee
        oftWithdrawWrapper.setMockFee(1 ether);

        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            2 ether,  // Max fee above actual
            recipientBytes32,
            DEST_EID
        );

        // Should succeed
        assertEq(oftWithdrawWrapper.lastAmount(), amount);
    }

    function test_WithdrawIntentLZ_SkipFeeCheck() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        // Set very high mock fee
        oftWithdrawWrapper.setMockFee(100 ether);

        // type(uint256).max should skip fee check
        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );

        // Should succeed despite high fee
        assertEq(oftWithdrawWrapper.lastAmount(), amount);
    }

    // ============ Access Control Tests ============

    function test_RevertIf_NonExecutorCallsWithdrawIntentLZ() public {
        address nonExecutor = makeAddr("nonExecutor");

        vm.prank(nonExecutor);
        vm.expectRevert(IntentExecutorBase.NotIntentExecutor.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            _addressToBytes32(owner),
            DEST_EID
        );
    }

    // ============ Withdraw Limit Tests ============

    function test_WithdrawLimit_LZ() public {
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        // Set limit to 2 per bucket
        bridgeIntent.setBucketParams(60, 2);

        vm.startPrank(executor);

        // First two should succeed
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            1 ether,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );

        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            1 ether,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );

        // Third should fail
        vm.expectRevert(WithdrawBridgeIntent.WithdrawLimitReached.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            1 ether,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );

        vm.stopPrank();

        // After bucket expires, should work again
        vm.warp(block.timestamp + 61);

        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            1 ether,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );
    }

    // ============ Bytes32 Destination Tests (Non-EVM) ============

    function test_WithdrawIntentLZ_Bytes32Destination_Solana() public {
        // Simulating a Solana address (32 bytes, doesn't fit in address)
        bytes32 solanaAddress = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        // SCW must approve this non-EVM destination
        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(solanaAddress);

        assertTrue(bridgeIntent.isApprovedDestination(address(scw), solanaAddress, false));

        // Owner as bytes32 should NOT equal solana address
        assertFalse(_addressToBytes32(owner) == solanaAddress);

        // This should work because it's approved (non-EVM EID, only checks explicit destinations)
        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            solanaAddress,
            NON_EVM_DEST_EID
        );

        // Verify the solana address was passed correctly
        assertEq(oftWithdrawWrapper.lastRecipient(), solanaAddress);
    }

    function test_RevertIf_UnapprovedSolanaDestination() public {
        bytes32 solanaAddress = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        // NOT approved
        assertFalse(bridgeIntent.isApprovedDestination(address(scw), solanaAddress, false));

        vm.prank(executor);
        vm.expectRevert(WithdrawBridgeIntent.InvalidRecipient.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            solanaAddress,
            NON_EVM_DEST_EID
        );
    }

    function test_RevertIf_OwnerSentToNonEvmEID() public {
        // Owner should NOT be auto-approved for non-EVM destinations
        bytes32 ownerBytes32 = _addressToBytes32(owner);

        vm.prank(executor);
        vm.expectRevert(WithdrawBridgeIntent.InvalidRecipient.selector);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            ownerBytes32,
            NON_EVM_DEST_EID
        );
    }

    function test_WithdrawIntentLZ_OwnerExplicitlyApprovedForNonEvmEID() public {
        // Even though owner is auto-approved for EVM EIDs, for non-EVM we need explicit approval
        bytes32 ownerBytes32 = _addressToBytes32(owner);

        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(ownerBytes32);

        vm.prank(executor);
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            10 ether,
            type(uint256).max,
            ownerBytes32,
            NON_EVM_DEST_EID
        );

        assertEq(oftWithdrawWrapper.lastRecipient(), ownerBytes32);
    }

    // ============ Event Tests ============

    function test_Events_ApprovedDestination() public {
        bytes32 destination = _addressToBytes32(alternativeRecipient);

        vm.prank(address(scw));
        vm.expectEmit(true, true, false, false);
        emit WithdrawBridgeIntent.DestinationApproved(address(scw), destination);
        bridgeIntent.addApprovedDestination(destination);

        vm.prank(address(scw));
        vm.expectEmit(true, true, false, false);
        emit WithdrawBridgeIntent.DestinationRemoved(address(scw), destination);
        bridgeIntent.removeApprovedDestination(destination);
    }

    function test_Events_IntentWithdrawLZ() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = _addressToBytes32(owner);

        vm.prank(executor);
        vm.expectEmit(true, true, false, true);
        emit WithdrawBridgeIntent.IntentWithdrawLZ(
            address(scw),
            address(token),
            amount,
            recipientBytes32,
            DEST_EID
        );
        bridgeIntent.executeWithdrawIntentLZ(
            address(scw),
            address(token),
            amount,
            type(uint256).max,
            recipientBytes32,
            DEST_EID
        );
    }

    function test_SetEvmEID() public {
        uint32 eid = 30101;

        assertFalse(bridgeIntent.evmEIDs(eid));

        vm.expectEmit(true, false, false, true);
        emit WithdrawBridgeIntent.EvmEIDSet(eid, true);
        bridgeIntent.setEvmEID(eid, true);

        assertTrue(bridgeIntent.evmEIDs(eid));

        vm.expectEmit(true, false, false, true);
        emit WithdrawBridgeIntent.EvmEIDSet(eid, false);
        bridgeIntent.setEvmEID(eid, false);

        assertFalse(bridgeIntent.evmEIDs(eid));
    }

    function test_RevertIf_NonOwnerSetsEvmEID() public {
        vm.prank(executor);
        vm.expectRevert();
        bridgeIntent.setEvmEID(30101, true);
    }

    // ============ Edge Cases ============

    function test_GetApprovedDestinations() public {
        bytes32[] memory destinationsEmpty = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinationsEmpty.length, 0);

        bytes32 dest1 = _addressToBytes32(makeAddr("dest1"));
        bytes32 dest2 = _addressToBytes32(makeAddr("dest2"));
        bytes32 dest3 = _addressToBytes32(makeAddr("dest3"));

        vm.startPrank(address(scw));
        bridgeIntent.addApprovedDestination(dest1);
        bridgeIntent.addApprovedDestination(dest2);
        bridgeIntent.addApprovedDestination(dest3);
        vm.stopPrank();

        bytes32[] memory destinations = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinations.length, 3);
        assertEq(destinations[0], dest1);
        assertEq(destinations[1], dest2);
        assertEq(destinations[2], dest3);
    }

    function test_addingDuplicateDestinationDoesNothing() public {
        bytes32 destination = _addressToBytes32(alternativeRecipient);

        vm.startPrank(address(scw));
        bridgeIntent.addApprovedDestination(destination);

        assertEq(bridgeIntent.getApprovedDestinations(address(scw)).length, 1);

        bridgeIntent.addApprovedDestination(destination);
        assertEq(bridgeIntent.getApprovedDestinations(address(scw)).length, 1);

        vm.stopPrank();
    }

    function test_RevertIf_RemovingNonExistentDestination() public {
        bytes32 destination = _addressToBytes32(alternativeRecipient);

        vm.prank(address(scw));
        vm.expectRevert(WithdrawBridgeIntent.DestinationNotFound.selector);
        bridgeIntent.removeApprovedDestination(destination);
    }

    function test_RemoveDestination_SwapAndPop() public {
        bytes32 dest1 = _addressToBytes32(makeAddr("dest1"));
        bytes32 dest2 = _addressToBytes32(makeAddr("dest2"));
        bytes32 dest3 = _addressToBytes32(makeAddr("dest3"));

        vm.startPrank(address(scw));
        bridgeIntent.addApprovedDestination(dest1);
        bridgeIntent.addApprovedDestination(dest2);
        bridgeIntent.addApprovedDestination(dest3);

        // Remove middle element
        bridgeIntent.removeApprovedDestination(dest2);
        vm.stopPrank();

        bytes32[] memory destinations = bridgeIntent.getApprovedDestinations(address(scw));
        assertEq(destinations.length, 2);
        // After swap and pop, dest3 should be in position 1
        assertEq(destinations[0], dest1);
        assertEq(destinations[1], dest3);
    }

    function test_DifferentSCWsHaveSeparateDestinations() public {
        MockLightAccount scw2 = new MockLightAccount(makeAddr("owner2"));
        token.mint(address(scw2), initialBalance);

        vm.prank(address(scw2));
        token.approve(address(bridgeIntent), type(uint256).max);

        bytes32 destination = _addressToBytes32(alternativeRecipient);

        // Only scw1 approves
        vm.prank(address(scw));
        bridgeIntent.addApprovedDestination(destination);

        // scw1 can use this destination
        assertTrue(bridgeIntent.isApprovedDestination(address(scw), destination, true));

        // scw2 cannot use this destination
        assertFalse(bridgeIntent.isApprovedDestination(address(scw2), destination, true));

        // Verify arrays are separate
        bytes32[] memory scw1Dests = bridgeIntent.getApprovedDestinations(address(scw));
        bytes32[] memory scw2Dests = bridgeIntent.getApprovedDestinations(address(scw2));
        assertEq(scw1Dests.length, 1);
        assertEq(scw2Dests.length, 0);
    }

    // ============ Helper Functions ============

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    receive() external payable {}
}

// ============ Mock Contracts ============

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockLightAccount {
    address private _owner;

    constructor(address owner_) {
        _owner = owner_;
    }

    function owner() external view returns (address) {
        return _owner;
    }
}

contract MockOFTWithdrawWrapper is IOFTWithdrawWrapper {
    address public lastToken;
    uint256 public lastAmount;
    bytes32 public lastRecipient;
    uint32 public lastDestEID;
    uint256 public mockFee;

    function withdrawToChain(
        address token,
        uint256 amount,
        address toAddress,
        uint32 destEID
    ) external override {
        lastToken = token;
        lastAmount = amount;
        lastRecipient = bytes32(uint256(uint160(toAddress)));
        lastDestEID = destEID;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdrawToChainBytes32(
        address token,
        uint256 amount,
        bytes32 toAddressBytes32,
        uint32 destEID
    ) external override {
        lastToken = token;
        lastAmount = amount;
        lastRecipient = toAddressBytes32;
        lastDestEID = destEID;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function getFeeInToken(
        address,
        uint256,
        uint32
    ) external view override returns (uint256) {
        return mockFee;
    }

    function setMockFee(uint256 fee) external {
        mockFee = fee;
    }
}

contract MockSocketWithdrawWrapper is ISocketWithdrawWrapper {
    function withdrawToChain(
        address,
        uint256,
        address,
        address,
        address,
        uint256
    ) external pure override {}

    function getFeeInToken(
        address,
        address,
        address,
        uint256
    ) external pure override returns (uint256) {
        return 0;
    }
}


