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
        _reroll(oldXXYYZZ, _callerSeed(_numMinted));
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
        uint256 seed = _callerSeed(_numMinted);
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
        _validatePayment(REROLL_SPECIFIC_PRICE, 1);
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
    }

    /**
     * @notice Burn and re-mint a number of tokens with specific hex values.
     * @param oldIds The 6-hex-digit token IDs to burn
     * @param newIds The 6-hex-digit token IDs to mint
     * @param salts The salts used in the commitments for the new ID commitments
     */
    function batchRerollSpecific(uint256[] calldata oldIds, uint256[] calldata newIds, bytes32[] calldata salts)
        public
        payable
    {
        if (oldIds.length != newIds.length || oldIds.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        unchecked {
            _validatePayment(REROLL_SPECIFIC_PRICE, oldIds.length);
        }
        for (uint256 i; i < oldIds.length;) {
            _rerollSpecific(oldIds[i], newIds[i], salts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function batchRerollSpecific(uint256[] calldata oldIds, uint256[] calldata newIds, bytes32 salt) public payable {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }
        unchecked {
            _validatePayment(REROLL_SPECIFIC_PRICE, oldIds.length);
        }
        bytes32 computedCommitment = computeBatchCommitment(msg.sender, newIds, salt);
        for (uint256 i; i < oldIds.length;) {
            _rerollSpecificWithCommitment(oldIds[i], newIds[i], computedCommitment);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Burn and re-mint a token with a specific hex ID, then finalize it.
     */
    function rerollSpecificAndFinalize(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) public payable {
        unchecked {
            _validatePayment(REROLL_SPECIFIC_PRICE + FINALIZE_PRICE, 1);
        }
        _rerollSpecific(oldXXYYZZ, newXXYYZZ, salt);
        // won't re-validate price, but above function already did
        _finalize(newXXYYZZ);
    }

    /**
     * @notice Burn and re-mint a number of tokens with specific hex values, then finalize them.
     */

    function batchRerollSpecificAndFinalize(
        uint256[] calldata oldIds,
        uint256[] calldata newIds,
        bytes32[] calldata salts
    ) public payable {
        if (oldIds.length != newIds.length || oldIds.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        unchecked {
            _validatePayment(REROLL_SPECIFIC_PRICE + FINALIZE_PRICE, oldIds.length);
        }
        for (uint256 i; i < oldIds.length;) {
            uint256 newId = newIds[i];
            _rerollSpecific(oldIds[i], newId, salts[i]);
            _finalize(newId);
            unchecked {
                ++i;
            }
        }
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
    {
        if (oldIds.length != newIds.length) {
            revert ArrayLengthMismatch();
        }

        unchecked {
            _validatePayment(REROLL_SPECIFIC_PRICE + FINALIZE_PRICE, oldIds.length);
        }

        bytes32 computedCommitment = computeBatchCommitment(msg.sender, newIds, salt);
        for (uint256 i; i < oldIds.length;) {
            uint256 newId = newIds[i];
            _rerollSpecificWithCommitment(oldIds[i], newId, computedCommitment);
            _finalize(newId);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a new hex ID
    function _reroll(uint256 oldXXYYZZ, uint256 seed) internal {
        _validateReroll(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        uint256 tokenId = _findAvailableHex(seed);
        _mint(msg.sender, tokenId);
    }

    ///@dev Validate msg.value, msg.sender, and finalized status of an ID for rerolling
    function _validateReroll(uint256 id) internal view {
        // only owner can reroll; also checks for existence
        if (msg.sender != ownerOf(id)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot reroll
        if (_isFinalized(id)) {
            revert AlreadyFinalized();
        }
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a specific new hex ID
    function _rerollSpecific(uint256 oldXXYYZZ, uint256 newXXYYZZ, bytes32 salt) internal {
        _validateReroll(oldXXYYZZ);
        // burn old token
        _burn(oldXXYYZZ);
        _mintSpecific(newXXYYZZ, salt);
    }

    ///@dev Validate a reroll and then burn and re-mint a token with a specific new hex ID
    function _rerollSpecificWithCommitment(uint256 oldId, uint256 newId, bytes32 computedCommitment) internal {
        _validateReroll(oldId);
        // burn old token
        _burn(oldId);
        _mintSpecificWithCommitment(newId, computedCommitment);
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
        // only owner can finalize; also checks for existence
        if (msg.sender != ownerOf(xxyyzz)) {
            revert OnlyTokenOwner();
        }
        // once finalized, cannot finalize again
        // send ether directly to contract if you'd like to donate :)
        if (_isFinalized(xxyyzz)) {
            revert AlreadyFinalized();
        }

        // set finalized flag
        _finalizeToken(xxyyzz, msg.sender);
    }

    ///@dev Finalize a token, updating its metadata with a "Finalizer" trait, and preventing it from being rerolled in the future.
    function _finalizeToken(uint256 xxyyzz, address finalizer) internal {
        finalizers[xxyyzz] = finalizer;
        _setExtraData(xxyyzz, 1);
    }
}
