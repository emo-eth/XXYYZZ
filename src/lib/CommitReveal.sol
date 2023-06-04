// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CommitReveal {
    error InvalidCommitment(uint256 committedTimestamp);
    error MaxBatchSizeExceeded();

    uint256 private constant INVALID_COMMITMENT_SELECTOR = 0x31e63ea0;

    uint256 public immutable COMMITMENT_LIFESPAN;
    uint256 public immutable COMMITMENT_DELAY;
    uint256 public immutable MAX_BATCH_SIZE;

    constructor(uint256 commitmentLifespan, uint256 commitmentDelay, uint256 maxBatchSize) {
        COMMITMENT_LIFESPAN = commitmentLifespan;
        COMMITMENT_DELAY = commitmentDelay;
        MAX_BATCH_SIZE = maxBatchSize;
    }

    ///@dev mapping of user to key to commitment hash to timestamp.
    mapping(address user => mapping(bytes32 commitment => uint256 timestamp)) public commitments;

    /**
     * @notice Commit a hash to the contract, to be retrieved and verified after a delay. A commitment is valid only
     *         after COMMITMENT_DELAY seconds have passed, and is only valid for COMMITMENT_LIFESPAN seconds.
     * @param commitment The hash to commit.
     */
    function commit(bytes32 commitment) public {
        commitments[msg.sender][commitment] = block.timestamp;
    }

    /**
     * @notice Commit multiple hashes to the contract, to be retrieved and verified after a delay. A commitment is
     *         valid only after COMMITMENT_DELAY seconds have passed, and is only valid for COMMITMENT_LIFESPAN
     *         seconds.
     */
    function batchCommit(bytes32[] calldata _commitments) public {
        if (_commitments.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        for (uint256 i = 0; i < _commitments.length;) {
            commit(_commitments[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Assert that a commitment has been made and is within a valid time
     *      window.
     * @param computedCommitmentHash The derived commitment hash to verify.
     */
    function _assertCommittedReveal(bytes32 computedCommitmentHash) internal view {
        // retrieve the timestamp of the commitment (if it exists)
        uint256 retrievedTimestamp = commitments[msg.sender][computedCommitmentHash];
        // compute the time difference
        uint256 timeDiff;
        // unchecked; assume blockchain time is monotonically increasing
        unchecked {
            timeDiff = block.timestamp - retrievedTimestamp;
        }
        uint256 commitmentLifespan = COMMITMENT_LIFESPAN;
        uint256 commitmentDelay = COMMITMENT_DELAY;
        assembly {
            // if the time difference is greater than the commitment lifespan,
            // the commitment has expired
            // if the time difference is less than the commitment delay, the
            // commitment is pending
            let invalidCommitment := or(gt(timeDiff, commitmentLifespan), lt(timeDiff, commitmentDelay))
            if invalidCommitment {
                mstore(0, INVALID_COMMITMENT_SELECTOR)
                mstore(0x20, retrievedTimestamp)
                revert(0x1c, 0x24)
            }
        }
    }
}
