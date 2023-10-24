// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {BasePaymaster} from "../../lib/account-abstraction/contracts/core/BasePaymaster.sol";
import {UserOperation} from "../../lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {IEntryPoint} from "../../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract VerifyingPaymaster is BasePaymaster {
    /// @dev If this signer is approved to authorize payouts
    mapping(address signer => bool) public isSigner;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {}

    function setSigner(address signer, bool isAuthorized) external onlyOwner {
        isSigner[signer] = isAuthorized;
    }

    /**
     * @dev Verifies that the user operation is signed by a whitelisted signer.
     */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, /*userOpHash*/ uint256 /*maxCost*/ )
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        bytes calldata batchCallData = userOp.callData;

        bytes memory sigs = bytes(userOp.paymasterAndData[20:85]); // 65 bytes:  r:[32], s:[32], v:[1]

        bytes32 signedHash = keccak256(abi.encode(batchCallData, userOp.sender, userOp.maxFeePerGas));

        address signer = ECDSA.recover(signedHash, sigs);

        if (!isSigner[signer]) revert("SignaturePaymaster: invalid signer");

        // do no verification
        return ("", 0);
    }
}
