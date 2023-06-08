// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";

abstract contract XXYYZZMint is XXYYZZCore {
    uint256 public immutable MAX_MINT_CLOSE_TIMESTAMP;

    constructor(address initialOwner, uint256 maxBatchSize) XXYYZZCore(initialOwner, maxBatchSize) {
        MAX_MINT_CLOSE_TIMESTAMP = block.timestamp + 10 days;
        mintCloseTimestamp = uint64(MAX_MINT_CLOSE_TIMESTAMP);
    }

    /**
     * @notice Set the mint close timestamp. Close can only set to be earlier than MAX_MINT_CLOSE_TIMESTAMP. onlyOwner.
     */
    function setMintCloseTimestamp(uint256 timestamp) external onlyOwner {
        if (timestamp > MAX_MINT_CLOSE_TIMESTAMP) {
            revert InvalidTimestamp();
        }
        mintCloseTimestamp = uint64(timestamp);
    }

    //////////
    // MINT //
    //////////

    /**
     * @notice Mint a token with a pseudorandom hex value.
     */
    function mint() public payable {
        uint256 newAmount = _checkMintAndIncrementNumMinted(1);
        // get pseudorandom hex id – doesn't need to be derived from caller
        uint256 tokenId = _findAvailableHex(newAmount);
        _mint(msg.sender, tokenId);
    }

    /**
     * @notice Mint a number of tokens with pseudorandom hex values.
     * @param quantity The number of tokens to mint
     */
    function mint(uint256 quantity) public payable {
        // check payment and quantity once
        uint256 newAmount = _checkMintAndIncrementNumMinted(quantity);
        for (uint256 i; i < quantity;) {
            // get pseudorandom hex id
            uint256 tokenId = _findAvailableHex(newAmount);
            _mint(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Mint a token with a specific hex value.
     *         A user must first call commit(bytes32) or batchCommit(bytes32[]) with the result(s) of
     *         computeCommittment(address,uint256,bytes32), and wait at least one minute.
     *         When calling mintSpecific, the "salt" should be the bytes32 salt provided to `computeCommitment` when
     *         creating the commitment hash.
     *
     *         Example: To register 0x123456 with salt bytes32(0xDEADBEEF)
     *             1. Call `computeCommitment(<minting addr>, 0x123456, bytes32(0xDEADBEEF))` for `bytes32 result`
     *             2. Call `commit(result)`
     *             3. Wait at least 1 minute, but less than 1 day
     *             4. Call `mintSpecific(0x123456, bytes32(0xDEADBEEF))`
     * @param xxyyzz The 6-hex-digit token ID to mint
     * @param salt The salt used in the commitment for the commitment
     */
    function mintSpecific(uint256 xxyyzz, bytes32 salt) public payable {
        _checkMintAndIncrementNumMinted(1);
        _mintSpecific(xxyyzz, salt);
    }

    function mintSpecificUnprotected(uint256 xxyyzz) public payable {
        // validate that the token doesn't already exist or has been finalized
        if (!_mintSpecificUnprotected(xxyyzz)) {
            revert Unavailable();
        }
        // technically violates checks/effects/interactions pattern – but safeMint is not used,
        // so there is no chance of reentrancy
        _checkMintAndIncrementNumMinted(1);
    }

    /**
     * @notice Mint a number of tokens with specific hex values.
     *         A user must first call commit(bytes32) with the result of computeBatchCommitment(address,uint256[],bytes32), and wait at least one minute.
     * @param ids The 6-hex-digit token IDs to mint
     * @param salt The salt used in the batch commitment
     */
    function batchMintSpecific(uint256[] calldata ids, bytes32 salt) public payable returns (bool[] memory) {
        if (ids.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        _validateTimestamp();
        _validatePayment(MINT_PRICE, ids.length);
        bytes32 computedCommitment = computeBatchCommitment(msg.sender, ids, salt);
        _assertCommittedReveal(computedCommitment);
        return _batchMintAndIncrementAndRefund(ids);
    }

    function batchMintSpecificUnprotected(uint256[] calldata ids) public payable returns (bool[] memory) {
        if (ids.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        _validateTimestamp();
        _validatePayment(MINT_PRICE, ids.length);

        return _batchMintAndIncrementAndRefund(ids);
    }

    function _batchMintAndIncrementAndRefund(uint256[] calldata ids) internal returns (bool[] memory) {
        bool[] memory minted = new bool[](ids.length);
        uint256 quantityMinted;
        for (uint256 i; i < ids.length;) {
            if (_mintSpecificUnprotected(ids[i])) {
                minted[i] = true;
                unchecked {
                    ++quantityMinted;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (quantityMinted == 0) {
            revert NoneAvailable();
        }

        _incrementNumMintedAndRefundOverpayment(quantityMinted);
        return minted;
    }

    /**
     * @dev Check payment and quantity validation – quantityRequested for payment, quantityAvailable for updating
     *      the number of minted tokens, which may be different
     * @param quantityRequested The number of tokens requested by the user, which must be paid for
     * @return The new number of minted tokens
     */
    function _checkMintAndIncrementNumMinted(uint256 quantityRequested) internal returns (uint256) {
        _validateTimestamp();
        _validatePayment(MINT_PRICE, quantityRequested);

        // increment supply before minting
        uint256 newAmount;
        // this can be unchecked because an ID can only be minted once, and all IDs are validated to be uint24s
        unchecked {
            newAmount = _numMinted + uint64(quantityRequested);
        }
        _numMinted = uint64(newAmount);
        return newAmount;
    }

    function _incrementNumMintedAndRefundOverpayment(uint256 numMinted) internal returns (uint256) {
        uint256 newAmount;
        // this can be unchecked because an ID can only be minted once, and all IDs are validated to be uint24s
        unchecked {
            newAmount = _numMinted + numMinted;
        }
        _numMinted = uint64(newAmount);
        _refundOverpayment(MINT_PRICE, numMinted);
        return newAmount;
    }

    function _validateTimestamp() internal view {
        if (block.timestamp > mintCloseTimestamp) {
            revert MintClosed();
        }
    }
}
