// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";

abstract contract XXYYZZRerollFinalize is XXYYZZCore {
    ////////////
    // REROLL //
    ////////////
    /**
     * @notice Burn a token you own and mint a new one with a pseudorandom hex value.
     * @param oldXXYYZZ The 6-hex-digit token ID to burn
     */
    function reroll(uint256 oldXXYYZZ) public payable {
        _validatePayment(REROLL_PRICE, 1);
        // use the caller's seed to derive the new token ID
        _reroll(oldXXYYZZ, uint160(msg.sender));
    }

    /**
     * @notice Burn a number of tokens you own and mint new ones with pseudorandom hex values.
     * @param ids The 6-hex-digit token IDs to burn
     */
    function batchReroll(uint256[] calldata ids) public payable {
        // unchecked block is safe because there are at most 2^24 tokens
        unchecked {
            _validatePayment(REROLL_PRICE, ids.length);
        }
        // use the caller's seed to derive the new token IDs
        uint256 seed = uint256(uint160(msg.sender));
        for (uint256 i; i < ids.length;) {
            _reroll(ids[i], seed);
            unchecked {
                ++i;
                ++seed;
            }
        }
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID
     * @param oldXXYYZZ The 6-hex-digit token ID to burn
     * @param newXXYYZZ The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the new ID commitment
     */
    function rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        _validatePayment(REROLL_PRICE, 1);
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
    }

    function rerollSpecificUnprotected(uint256 oldXXYYZZ, uint256 newXXYYZZ) public payable {
        _validatePayment(REROLL_PRICE, 1);
        if (!_rerollSpecificUnprotected(oldXXYYZZ, newXXYYZZ)) {
            revert Unavailable();
        }
    }

    function batchRerollSpecific(uint256[] calldata oldIds, uint256[] calldata newIds, bytes32 salt)
        public
        payable
        returns (bool[] memory)
    {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }
        if (oldIds.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        _validatePayment(REROLL_PRICE, oldIds.length);
        bytes32 computedCommitment = computeBatchCommitment(msg.sender, newIds, salt);
        _assertCommittedReveal(computedCommitment);

        return _batchRerollAndRefund(oldIds, newIds);
    }

    function batchRerollSpecificUnprotected(uint256[] calldata oldIds, uint256[] calldata newIds)
        public
        payable
        returns (bool[] memory)
    {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }
        if (oldIds.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        unchecked {
            _validatePayment(REROLL_PRICE, oldIds.length);
        }
        return _batchRerollAndRefund(oldIds, newIds);
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID, then finalize it.
     */
    function rerollSpecificAndFinalize(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        unchecked {
            _validatePayment(REROLL_PRICE + FINALIZE_PRICE, 1);
        }
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
        // won't re-validate price, but above function already did
        _finalizeToken(newXXYYZZ, msg.sender);
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID, then finalize it.
     */
    function rerollSpecificAndFinalizeUnprotected(uint256 oldXXYYZZ, uint256 newXXYYZZ) public payable {
        unchecked {
            _validatePayment(REROLL_PRICE + FINALIZE_PRICE, 1);
        }
        if (!_rerollSpecificUnprotected(oldXXYYZZ, newXXYYZZ)) {
            revert Unavailable();
        }
        // won't re-validate price, but above function already did
        _finalizeToken(newXXYYZZ, msg.sender);
    }

    /**
     * @notice Burn and re-mint a number of tokens with specific hex values, then finalize them.
     * @param oldIds The 6-hex-digit token IDs to burn
     * @param newIds The 6-hex-digit token IDs to mint
     * @param salt The salt used in the batch commitment for the new ID commitment
     */
    function batchRerollSpecificAndFinalize(uint256[] calldata oldIds, uint256[] calldata newIds, bytes32 salt)
        public
        payable
        returns (bool[] memory)
    {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }
        if (oldIds.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        uint256 combinedPrice;

        unchecked {
            combinedPrice = REROLL_PRICE + FINALIZE_PRICE;
        }
        _validatePayment(combinedPrice, oldIds.length);

        bytes32 computedCommitment = computeBatchCommitment(msg.sender, newIds, salt);
        _assertCommittedReveal(computedCommitment);
        return _batchRerollAndFinalizeAndRefund(oldIds, newIds, combinedPrice);
    }

    function batchRerollSpecificAndFinalizeUnprotected(uint256[] calldata oldIds, uint256[] calldata newIds)
        public
        payable
        returns (bool[] memory)
    {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }
        if (oldIds.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        uint256 cumulativePrice;
        unchecked {
            cumulativePrice = REROLL_PRICE + FINALIZE_PRICE;
            _validatePayment(cumulativePrice, oldIds.length);
        }
        return _batchRerollAndFinalizeAndRefund(oldIds, newIds, cumulativePrice);
    }

    function _batchRerollAndRefund(uint256[] calldata oldIds, uint256[] calldata newIds)
        internal
        returns (bool[] memory)
    {
        bool[] memory rerolled = new bool[](oldIds.length);
        uint256 quantityRerolled;
        for (uint256 i; i < oldIds.length;) {
            if (_rerollSpecificUnprotected(oldIds[i], newIds[i])) {
                rerolled[i] = true;
                unchecked {
                    ++quantityRerolled;
                }
            }
            unchecked {
                ++i;
            }
        }
        // if none were rerolled, revert to avoid wasting gas
        if (quantityRerolled == 0) {
            revert NoneAvailable();
        }
        // refund any overpayment
        _refundOverpayment(REROLL_PRICE, quantityRerolled);

        return rerolled;
    }

    function _batchRerollAndFinalizeAndRefund(
        uint256[] calldata oldIds,
        uint256[] calldata newIds,
        uint256 cumulativePrice
    ) internal returns (bool[] memory) {
        bool[] memory rerolled = new bool[](oldIds.length);
        uint256 quantityRerolled;
        for (uint256 i; i < oldIds.length;) {
            if (_rerollSpecificUnprotected(oldIds[i], newIds[i])) {
                _finalizeToken(newIds[i], msg.sender);
                rerolled[i] = true;
                unchecked {
                    ++quantityRerolled;
                }
            }
            unchecked {
                ++i;
            }
        }
        // if none were rerolled, revert to avoid wasting gas
        if (quantityRerolled == 0) {
            revert NoneAvailable();
        }
        // refund any overpayment
        _refundOverpayment(cumulativePrice, quantityRerolled);

        return rerolled;
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a new hex ID
    function _reroll(uint256 oldXXYYZZ, uint256 seed) internal {
        _checkCallerIsOwnerAndNotFinalized(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        uint256 tokenId = _findAvailableHex(seed);
        _mint(msg.sender, tokenId);
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a specific new hex ID
    function _rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) internal {
        _checkCallerIsOwnerAndNotFinalized(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        _mintSpecific(newXXYYZZ, salt);
    }

    /**
     * @dev Validate an old tokenId is rerollable, mint a token with a specific new hex ID (if available)
     *      and burn the old token.
     * @param oldXXYYZZ The old ID to reroll
     * @param newXXYYZZ The new ID to mint
     * @return Whether the mint succeeded, ie, the new ID was available
     */
    function _rerollSpecificUnprotected(uint256 oldXXYYZZ, uint256 newXXYYZZ) internal returns (bool) {
        _checkCallerIsOwnerAndNotFinalized(oldXXYYZZ);
        // only burn old token if mint succeeded
        if (_mintSpecificUnprotected(newXXYYZZ)) {
            _burn(oldXXYYZZ);
            return true;
        }
        return false;
    }

    //////////////
    // FINALIZE //
    //////////////

    /**
     * @notice Finalize a token, which updates its metadata with a "Finalizer" trait and prevents it from being
     *         rerolled in the future.
     * @param xxyyzz The 6-hex-digit token ID to finalize. Must be owned by the caller.
     */
    function finalize(uint256 xxyyzz) public payable {
        _validatePayment(FINALIZE_PRICE, 1);
        _finalize(xxyyzz);
    }

    /**
     * @notice Finalize a number of tokens, which updates their metadata with a "Finalizer" trait and prevents them
     *         from being rerolled in the future. The caller must pay the finalization price for each token, and must
     *         own all tokens.
     * @param ids The 6-hex-digit token IDs to finalize
     */
    function batchFinalize(uint256[] calldata ids) public payable {
        _validatePayment(FINALIZE_PRICE, ids.length);
        for (uint256 i; i < ids.length;) {
            _finalize(ids[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _finalize(uint256 xxyyzz) internal {
        _checkCallerIsOwnerAndNotFinalized(xxyyzz);
        // set finalized flag
        _finalizeToken(xxyyzz, msg.sender);
    }

    ///@dev Finalize a token, updating its metadata with a "Finalizer" trait, and preventing it from being rerolled in the future.
    function _finalizeToken(uint256 xxyyzz, address finalizer) internal {
        finalizers[xxyyzz] = finalizer;
        _setExtraData(xxyyzz, 1);
    }
}
