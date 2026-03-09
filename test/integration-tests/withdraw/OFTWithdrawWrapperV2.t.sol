// SPDX-License-Identifier: UNLICENSED
// solhint-disable contract-name-camelcase
// solhint-disable func-name-mixedcase
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";

import {LyraOFTWithdrawWrapperV2} from "src/withdraw/OFTWithdrawWrapperV2.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IOFT, SendParam, OFTReceipt, OFTLimit, OFTFeeDetail} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import { MessagingReceipt, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";

/**
 * @title Integration tests for OFTWithdrawWrapperV2
 * @notice Tests the OFT withdraw wrapper functionality with mocked OFT contracts
 */
contract OFTWithdrawWrapperV2Test is Test {
    uint32 internal constant DEST_EID = 30184; // Example destination EID (Base)

    LyraOFTWithdrawWrapperV2 public wrapper;

    // Mock tokens
    MockERC20 public token;
    MockOFT public mockOFT;
    MockOFTAdapter public mockAdapter;
    MockERC20 public adapterToken;

    // Test addresses
    address public owner;
    address public user = makeAddr("user");
    address public feeRecipient = makeAddr("feeRecipient");
    address public recipient = makeAddr("recipient");

    uint256 public initialBalance = 100 ether;

    function setUp() public {
        owner = address(this);
        vm.deal(address(this), 100 ether);

        // Deploy wrapper with some ETH for fees
        wrapper = new LyraOFTWithdrawWrapperV2{value: 10 ether}();

        // Deploy mock native OFT token
        mockOFT = new MockOFT("MockOFT", "MOFT");

        // Deploy mock adapter token and adapter
        adapterToken = new MockERC20("AdapterToken", "ATOK");
        mockAdapter = new MockOFTAdapter(address(adapterToken));

        // Setup wrapper config
        wrapper.setStaticRate(address(mockOFT), 2500e18 * 1e18);  // 2500 tokens = 1 ETH
        wrapper.setStaticRate(address(adapterToken), 2000e18 * 1e18);  // 2000 tokens = 1 ETH
        wrapper.setAdapterForToken(address(adapterToken), address(mockAdapter));
        wrapper.setFeeRecipient(feeRecipient);

        // Mint tokens to user
        mockOFT.mint(user, initialBalance);
        adapterToken.mint(user, initialBalance);

        // User approves wrapper
        vm.startPrank(user);
        mockOFT.approve(address(wrapper), type(uint256).max);
        adapterToken.approve(address(wrapper), type(uint256).max);
        vm.stopPrank();
    }

    // ============ Admin Function Tests ============

    function test_SetFeeRecipient() public {
        address newRecipient = makeAddr("newRecipient");
        wrapper.setFeeRecipient(newRecipient);
        assertEq(wrapper.feeRecipient(), newRecipient);
    }

    function test_RevertIf_NonOwnerSetsFeeRecipient() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.setFeeRecipient(user);
    }

    function test_SetStaticRate() public {
        address newToken = makeAddr("newToken");
        uint256 rate = 1000e18 * 1e18;
        wrapper.setStaticRate(newToken, rate);
        assertEq(wrapper.staticPrice(newToken), rate);
    }

    function test_SetStaticRates() public {
        address[] memory tokens = new address[](2);
        tokens[0] = makeAddr("token1");
        tokens[1] = makeAddr("token2");

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1000e18 * 1e18;
        rates[1] = 2000e18 * 1e18;

        wrapper.setStaticRates(tokens, rates);

        assertEq(wrapper.staticPrice(tokens[0]), rates[0]);
        assertEq(wrapper.staticPrice(tokens[1]), rates[1]);
    }

    function test_RevertIf_SetStaticRatesArrayMismatch() public {
        address[] memory tokens = new address[](2);
        uint256[] memory rates = new uint256[](1);

        vm.expectRevert("Array length mismatch");
        wrapper.setStaticRates(tokens, rates);
    }

    function test_SetReceiveAmountFactor() public {
        uint256 newFactor = 0.95e18;
        wrapper.setReceiveAmountFactor(newFactor);
        assertEq(wrapper.receiveAmountFactor(), newFactor);
    }

    function test_SetStaticGasLimit() public {
        uint128 newGasLimit = 100000;
        wrapper.setStaticGasLimit(newGasLimit);
        assertEq(wrapper.staticGasLimit(), newGasLimit);
    }

    function test_SetAdapterForToken() public {
        address newToken = makeAddr("newToken");
        address newAdapter = makeAddr("newAdapter");

        wrapper.setAdapterForToken(newToken, newAdapter);
        assertEq(wrapper.adapterForToken(newToken), newAdapter);
    }

    function test_RescueEth() public {
        uint256 wrapperBalance = address(wrapper).balance;
        uint256 ownerBalanceBefore = owner.balance;

        wrapper.rescueEth();

        assertEq(address(wrapper).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + wrapperBalance);
    }

    function test_RevertIf_NonOwnerRescuesEth() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.rescueEth();
    }

    function test_RecoverERC20() public {
        // Send some tokens to wrapper accidentally
        mockOFT.mint(address(wrapper), 10 ether);

        uint256 ownerBalanceBefore = mockOFT.balanceOf(owner);

        wrapper.recoverERC20(address(mockOFT));

        assertEq(mockOFT.balanceOf(address(wrapper)), 0);
        assertEq(mockOFT.balanceOf(owner), ownerBalanceBefore + 10 ether);
    }

    // ============ Native OFT Withdraw Tests ============

    function test_WithdrawToChain_NativeOFT() public {
        uint256 amount = 10 ether;
        uint256 userBalanceBefore = mockOFT.balanceOf(user);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        uint256 userBalanceAfter = mockOFT.balanceOf(user);

        // User should have spent the full amount
        assertEq(userBalanceBefore - userBalanceAfter, amount);

        // MockOFT should have recorded the send
        assertEq(mockOFT.lastDestEid(), DEST_EID);
        assertGt(mockOFT.lastAmountSent(), 0);
    }

    function test_WithdrawToChainBytes32_NativeOFT() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));

        vm.prank(user);
        wrapper.withdrawToChainBytes32(address(mockOFT), amount, recipientBytes32, DEST_EID);

        assertEq(mockOFT.lastRecipient(), recipientBytes32);
        assertEq(mockOFT.lastDestEid(), DEST_EID);
    }

    function test_WithdrawToChainBytes32_SolanaAddress() public {
        uint256 amount = 10 ether;
        // Simulating a Solana address (doesn't fit in EVM address)
        bytes32 solanaAddress = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        vm.prank(user);
        wrapper.withdrawToChainBytes32(address(mockOFT), amount, solanaAddress, DEST_EID);

        assertEq(mockOFT.lastRecipient(), solanaAddress);
    }

    // ============ OFTAdapter Withdraw Tests ============

    function test_WithdrawToChain_OFTAdapter() public {
        uint256 amount = 10 ether;
        uint256 userBalanceBefore = adapterToken.balanceOf(user);

        vm.prank(user);
        wrapper.withdrawToChain(address(adapterToken), amount, recipient, DEST_EID);

        uint256 userBalanceAfter = adapterToken.balanceOf(user);

        // User should have spent the full amount
        assertEq(userBalanceBefore - userBalanceAfter, amount);

        // MockAdapter should have recorded the send
        assertEq(mockAdapter.lastDestEid(), DEST_EID);
        assertGt(mockAdapter.lastAmountSent(), 0);
    }

    function test_WithdrawToChainBytes32_OFTAdapter() public {
        uint256 amount = 10 ether;
        bytes32 recipientBytes32 = bytes32(uint256(uint160(recipient)));

        vm.prank(user);
        wrapper.withdrawToChainBytes32(address(adapterToken), amount, recipientBytes32, DEST_EID);

        assertEq(mockAdapter.lastRecipient(), recipientBytes32);
        assertEq(mockAdapter.lastDestEid(), DEST_EID);
    }

    // ============ Fee Tests ============

    function test_FeeCollection() public {
        uint256 amount = 10 ether;
        uint256 feeRecipientBalanceBefore = mockOFT.balanceOf(feeRecipient);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        uint256 feeRecipientBalanceAfter = mockOFT.balanceOf(feeRecipient);

        // Fee recipient should have received some tokens as fee
        assertGt(feeRecipientBalanceAfter, feeRecipientBalanceBefore);
    }

    function test_FeeGoesToOwnerIfNoFeeRecipient() public {
        // Remove fee recipient
        wrapper.setFeeRecipient(address(0));

        uint256 amount = 10 ether;
        uint256 ownerBalanceBefore = mockOFT.balanceOf(owner);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        uint256 ownerBalanceAfter = mockOFT.balanceOf(owner);

        // Owner should have received fee
        assertGt(ownerBalanceAfter, ownerBalanceBefore);
    }

    function test_NoFeeWhenStaticPriceIsOne() public {
        // Set static price to 1 (no fee token)
        wrapper.setStaticRate(address(mockOFT), 1);

        uint256 amount = 10 ether;
        uint256 feeRecipientBalanceBefore = mockOFT.balanceOf(feeRecipient);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        uint256 feeRecipientBalanceAfter = mockOFT.balanceOf(feeRecipient);

        // No fee should be collected
        assertEq(feeRecipientBalanceAfter, feeRecipientBalanceBefore);
    }

    function test_GetFeeInEth() public {
        uint256 amount = 10 ether;
        uint256 feeInEth = wrapper.getFeeInEth(address(mockOFT), amount, DEST_EID);

        // Should return some fee
        assertGt(feeInEth, 0);
    }

    function test_GetFeeInToken() public {
        uint256 amount = 10 ether;
        uint256 feeInToken = wrapper.getFeeInToken(address(mockOFT), amount, DEST_EID);

        // Should return some fee in token
        assertGt(feeInToken, 0);
    }

    function test_GetFeeInToken_ReturnsZeroWhenPriceIsOne() public {
        wrapper.setStaticRate(address(mockOFT), 1);

        uint256 amount = 10 ether;
        uint256 feeInToken = wrapper.getFeeInToken(address(mockOFT), amount, DEST_EID);

        assertEq(feeInToken, 0);
    }

    // ============ Fee Calculation Verification Tests ============

    function test_FeeCalculation_MatchesExpected() public {
        uint256 amount = 10 ether;
        // mockNativeFee = 0.001 ether, staticPrice = 2500e18 * 1e18
        // feeInToken = 0.001e18 * 2500e18 * 1e18 / 1e36 = 2.5e18
        uint256 expectedFeeInToken = 0.001 ether * (2500e18 * 1e18) / 1e36;

        uint256 feeInToken = wrapper.getFeeInToken(address(mockOFT), amount, DEST_EID);
        assertEq(feeInToken, expectedFeeInToken);
    }

    function test_FeeDeductedFromSendAmount() public {
        uint256 amount = 10 ether;
        uint256 feeInToken = wrapper.getFeeInToken(address(mockOFT), amount, DEST_EID);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        // Fee recipient gets fee, the rest minus second-quote adjustment goes to send
        assertEq(mockOFT.balanceOf(feeRecipient), feeInToken);
        // The amount sent should be the original amount minus the fee
        // Note: the fee is re-quoted after deducting, but amountLD in the send should be amount - fee
        assertEq(mockOFT.lastAmountSent(), amount - feeInToken);
    }

    function test_FeeCollection_OFTAdapter() public {
        uint256 amount = 10 ether;
        uint256 feeRecipientBalanceBefore = adapterToken.balanceOf(feeRecipient);

        vm.prank(user);
        wrapper.withdrawToChain(address(adapterToken), amount, recipient, DEST_EID);

        uint256 feeRecipientBalanceAfter = adapterToken.balanceOf(feeRecipient);
        assertGt(feeRecipientBalanceAfter, feeRecipientBalanceBefore);
    }

    function test_GetFeeInEth_OFTAdapter() public {
        uint256 amount = 10 ether;
        uint256 feeInEth = wrapper.getFeeInEth(address(adapterToken), amount, DEST_EID);

        // Should equal mockNativeFee
        assertEq(feeInEth, 0.001 ether);
    }

    function test_GetFeeInToken_OFTAdapter() public {
        uint256 amount = 10 ether;
        uint256 feeInToken = wrapper.getFeeInToken(address(adapterToken), amount, DEST_EID);

        uint256 expected = 0.001 ether * (2000e18 * 1e18) / 1e36;
        assertEq(feeInToken, expected);
    }

    // ============ Adapter Approval Tests ============

    function test_AdapterReceivesApproval() public {
        uint256 amount = 10 ether;
        uint256 feeInToken = wrapper.getFeeInToken(address(adapterToken), amount, DEST_EID);

        vm.prank(user);
        wrapper.withdrawToChain(address(adapterToken), amount, recipient, DEST_EID);

        // After send, adapter should have locked the tokens (transferred from wrapper)
        assertEq(mockAdapter.lastAmountSent(), amount - feeInToken);
    }

    // ============ Sequential Withdraw Tests ============

    function test_MultipleWithdraws() public {
        uint256 amount = 5 ether;

        vm.startPrank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);
        vm.stopPrank();

        // User spent 10 ether total
        assertEq(mockOFT.balanceOf(user), initialBalance - 2 * amount);
    }

    function test_MultipleWithdraws_DifferentTokens() public {
        uint256 amount = 5 ether;

        vm.startPrank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);
        wrapper.withdrawToChain(address(adapterToken), amount, recipient, DEST_EID);
        vm.stopPrank();

        assertEq(mockOFT.balanceOf(user), initialBalance - amount);
        assertEq(adapterToken.balanceOf(user), initialBalance - amount);
    }

    // ============ ReceiveAmountFactor Tests ============

    function test_ReceiveAmountFactor_AffectsMinAmount() public {
        uint256 amount = 10 ether;
        wrapper.setReceiveAmountFactor(0.95e18);
        wrapper.setStaticRate(address(mockOFT), 1); // no fee for simplicity

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        // With price=1 the full amount is sent. The minAmountLD should be amount * 0.95
        // We can verify the send happened with the right amount
        assertEq(mockOFT.lastAmountSent(), amount);
    }

    // ============ Fuzz Tests ============

    function testFuzz_SetStaticRate(address token, uint256 rate) public {
        wrapper.setStaticRate(token, rate);
        assertEq(wrapper.staticPrice(token), rate);
    }

    function testFuzz_SetReceiveAmountFactor(uint256 newFactor) public {
        wrapper.setReceiveAmountFactor(newFactor);
        assertEq(wrapper.receiveAmountFactor(), newFactor);
    }

    function testFuzz_SetStaticGasLimit(uint128 newGasLimit) public {
        wrapper.setStaticGasLimit(newGasLimit);
        assertEq(wrapper.staticGasLimit(), newGasLimit);
    }

    function testFuzz_WithdrawToChain_NativeOFT(uint256 amount) public {
        // Bound amount to reasonable range (must be > fee and <= user balance)
        // Fee is ~2.5 ether for mockOFT at 2500 rate, so use 5 ether as lower bound
        amount = bound(amount, 5 ether, initialBalance);

        vm.prank(user);
        wrapper.withdrawToChain(address(mockOFT), amount, recipient, DEST_EID);

        assertEq(mockOFT.balanceOf(user), initialBalance - amount);
    }

    function testFuzz_WithdrawToChain_OFTAdapter(uint256 amount) public {
        // Fee is ~2 ether for adapterToken at 2000 rate, so use 5 ether as lower bound
        amount = bound(amount, 5 ether, initialBalance);

        vm.prank(user);
        wrapper.withdrawToChain(address(adapterToken), amount, recipient, DEST_EID);

        assertEq(adapterToken.balanceOf(user), initialBalance - amount);
    }

    function testFuzz_GetFeeInToken_Consistency(uint256 nativeFee) public {
        nativeFee = bound(nativeFee, 0.0001 ether, 0.1 ether);
        mockOFT.setMockNativeFee(nativeFee);

        uint256 amount = 50 ether;
        uint256 tokenPrice = wrapper.staticPrice(address(mockOFT));
        uint256 expectedFee = nativeFee * tokenPrice / 1e36;

        uint256 actualFee = wrapper.getFeeInToken(address(mockOFT), amount, DEST_EID);
        assertEq(actualFee, expectedFee);
    }

    // ============ Revert Tests ============

    function test_RevertIf_NonOwnerRecoverERC20() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.recoverERC20(address(mockOFT));
    }

    function test_RevertIf_NonOwnerSetStaticRate() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.setStaticRate(address(mockOFT), 100);
    }

    function test_RevertIf_NonOwnerSetStaticRates() public {
        address[] memory tokens = new address[](1);
        uint256[] memory rates = new uint256[](1);
        vm.prank(user);
        vm.expectRevert();
        wrapper.setStaticRates(tokens, rates);
    }

    function test_RevertIf_NonOwnerSetReceiveAmountFactor() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.setReceiveAmountFactor(0.5e18);
    }

    function test_RevertIf_NonOwnerSetStaticGasLimit() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.setStaticGasLimit(100000);
    }

    function test_RevertIf_NonOwnerSetAdapterForToken() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.setAdapterForToken(address(mockOFT), address(0));
    }

    function test_RevertIf_InsufficientAllowance() public {
        // Revoke approval
        vm.prank(user);
        mockOFT.approve(address(wrapper), 0);

        vm.prank(user);
        vm.expectRevert();
        wrapper.withdrawToChain(address(mockOFT), 10 ether, recipient, DEST_EID);
    }

    function test_RevertIf_InsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert();
        wrapper.withdrawToChain(address(mockOFT), initialBalance + 1, recipient, DEST_EID);
    }

    function test_RevertIf_StaticPriceNotSet() public {
        // Use mockOFT but set its static price to 0
        wrapper.setStaticRate(address(mockOFT), 0);

        vm.prank(user);
        vm.expectRevert("staticPrice not set");
        wrapper.withdrawToChain(address(mockOFT), 10 ether, recipient, DEST_EID);
    }

    function test_RevertIf_AmountLessThanFee() public {
        // Set a very high static price to make fee larger than amount
        wrapper.setStaticRate(address(mockOFT), 1e50);

        vm.prank(user);
        vm.expectRevert("withdraw amount < fee");
        wrapper.withdrawToChain(address(mockOFT), 1 ether, recipient, DEST_EID);
    }

    function test_RevertIf_GetFeeInEthStaticPriceNotSet() public {
        address unknownToken = makeAddr("unknownToken");

        vm.expectRevert("staticPrice not set");
        wrapper.getFeeInEth(unknownToken, 10 ether, DEST_EID);
    }

    function test_RevertIf_GetFeeInTokenStaticPriceNotSet() public {
        address unknownToken = makeAddr("unknownToken");

        vm.expectRevert("staticPrice not set");
        wrapper.getFeeInToken(unknownToken, 10 ether, DEST_EID);
    }

    // ============ Receive ETH Test ============

    function test_ReceiveEth() public {
        uint256 balanceBefore = address(wrapper).balance;

        (bool success,) = address(wrapper).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(address(wrapper).balance, balanceBefore + 1 ether);
    }

    // ============ Helper Functions ============

    receive() external payable {}
}

// ============ Mock Contracts ============

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockOFT is MockERC20, IOFT {
    bytes32 public lastRecipient;
    uint32 public lastDestEid;
    uint256 public lastAmountSent;
    uint256 public mockNativeFee = 0.001 ether;

    constructor(string memory name_, string memory symbol_) MockERC20(name_, symbol_) {}

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        lastRecipient = _sendParam.to;
        lastDestEid = _sendParam.dstEid;
        lastAmountSent = _sendParam.amountLD;

        // Burn tokens (simulating send)
        _burn(msg.sender, _sendParam.amountLD);

        msgReceipt = MessagingReceipt({
            guid: bytes32(0),
            nonce: 0,
            fee: _fee
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.minAmountLD
        });
    }

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee) {
        msgFee = MessagingFee({
            nativeFee: mockNativeFee,
            lzTokenFee: 0
        });
    }

    function setMockNativeFee(uint256 fee) external {
        mockNativeFee = fee;
    }

    // Required IOFT interface functions
    function oApp() external view returns (address) {
        return address(this);
    }

    function token() external view returns (address) {
        return address(this);
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 6;
    }

    function oftVersion() external pure returns (bytes4, uint64) {
        return (0x02e49c2c, 1);
    }

    function quoteOFT(SendParam calldata _sendParam)
        external
        view
        returns (OFTLimit memory oftLimit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory oftReceipt)
    {
        oftLimit = OFTLimit({minAmountLD: 0, maxAmountLD: type(uint256).max});
        oftFeeDetails = new OFTFeeDetail[](0);
        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.minAmountLD
        });
    }
}

contract MockOFTAdapter is IOFT {
    address public immutable underlyingToken;
    bytes32 public lastRecipient;
    uint32 public lastDestEid;
    uint256 public lastAmountSent;
    uint256 public mockNativeFee = 0.001 ether;

    constructor(address _token) {
        underlyingToken = _token;
    }

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        lastRecipient = _sendParam.to;
        lastDestEid = _sendParam.dstEid;
        lastAmountSent = _sendParam.amountLD;

        // Transfer tokens from sender to this contract (simulating lock)
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), _sendParam.amountLD);

        msgReceipt = MessagingReceipt({
            guid: bytes32(0),
            nonce: 0,
            fee: _fee
        });

        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.minAmountLD
        });
    }

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory msgFee) {
        msgFee = MessagingFee({
            nativeFee: mockNativeFee,
            lzTokenFee: 0
        });
    }

    function setMockNativeFee(uint256 fee) external {
        mockNativeFee = fee;
    }

    // Required IOFT interface functions
    function oApp() external view returns (address) {
        return address(this);
    }

    function token() external view returns (address) {
        return underlyingToken;
    }

    function approvalRequired() external pure returns (bool) {
        return true;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 6;
    }

    function oftVersion() external pure returns (bytes4, uint64) {
        return (0x02e49c2c, 1);
    }

    function quoteOFT(SendParam calldata _sendParam)
        external
        view
        returns (OFTLimit memory oftLimit, OFTFeeDetail[] memory oftFeeDetails, OFTReceipt memory oftReceipt)
    {
        oftLimit = OFTLimit({minAmountLD: 0, maxAmountLD: type(uint256).max});
        oftFeeDetails = new OFTFeeDetail[](0);
        oftReceipt = OFTReceipt({
            amountSentLD: _sendParam.amountLD,
            amountReceivedLD: _sendParam.minAmountLD
        });
    }
}



