// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";

abstract contract XXYYZZBurn is XXYYZZCore {
    //////////
    // BURN //
    //////////

    /**
     * @notice Permanently burn a token that the caller owns or is approved for.
     */
    function burn(uint256 xxyyzz) public {
        // cannot overflow as there are at most 2^24 tokens, and _numBurned is a uint128
        unchecked {
            _numBurned += 1;
        }
        _burn(msg.sender, xxyyzz);
    }

    /**
     * @notice Permanently burn multiple tokens. All must be owned by the same address.
     */
    function bulkBurn(uint256[] calldata ids) public {
        if (ids.length == 0) {
            revert NoIdsProvided();
        }
        address initialTokenOwner = _ownerOf(ids[0]);
        // validate that msg.sender has approval to burn all tokens
        if (!(initialTokenOwner == msg.sender || isApprovedForAll(initialTokenOwner, msg.sender))) {
            revert BulkBurnerNotApprovedForAll();
        }
        // safe because there are at most 2^24 tokens, and ownerships are checked
        unchecked {
            _numBurned += uint128(ids.length);
        }
        _burn(ids[0]);
        for (uint256 i = 1; i < ids.length;) {
            uint256 id = ids[i];
            // ensure that all tokens are owned by the same address
            if (_ownerOf(id) != initialTokenOwner) {
                revert OwnerMismatch();
            }
            // no need to specify msg.sender since they are approved for all tokens
            // this also checks token exists
            _burn(id);
            unchecked {
                ++i;
            }
        }
    }
}
