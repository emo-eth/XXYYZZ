// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {XXYYZZCore} from "./XXYYZZCore.sol";

abstract contract XXYYZZMint is XXYYZZCore {
    uint256 public immutable MAX_MINTS_PER_WALLET;
    uint256 public immutable MAX_MINT_CLOSE_TIMESTAMP;

    constructor(address initialOwner, uint256 maxMintsPerWallet) XXYYZZCore(initialOwner) {
        _initializeOwner(initialOwner);
        MAX_MINTS_PER_WALLET = maxMintsPerWallet;
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

    /**
     * @notice Mint a number of tokens with specific hex values.
     *         A user must first call commit(bytes32) with the result of computeCommittment(address,uint256,bytes32), and wait at least one minute.
     * @param ids The 6-hex-digit token IDs to mint
     * @param salts The salts used in the commitments for the tokens
     */
    function batchMintSpecific(uint256[] calldata ids, bytes32[] calldata salts) public payable {
        if (ids.length != salts.length) {
            revert ArrayLengthMismatch();
        }
        if (ids.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        _checkMintAndIncrementNumMinted(ids.length);
        bytes32[] memory computedCommitments = computeCommitments(msg.sender, ids, salts);
        for (uint256 i; i < ids.length;) {
            _mintSpecificWithCommitment(ids[i], computedCommitments[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Mint a number of tokens with specific hex values.
     *         A user must first call commit(bytes32) with the result of computeBatchCommitment(address,uint256[],bytes32), and wait at least one minute.
     * @param ids The 6-hex-digit token IDs to mint
     * @param salt The salt used in the batch commitment
     */
    function batchMintSpecific(uint256[] calldata ids, bytes32 salt) public payable {
        if (ids.length > MAX_BATCH_SIZE) {
            revert MaxBatchSizeExceeded();
        }
        _checkMintAndIncrementNumMinted(ids.length);
        bytes32 computedCommitment = computeBatchCommitment(msg.sender, ids, salt);
        for (uint256 i; i < ids.length;) {
            _mintSpecificWithCommitment(ids[i], computedCommitment);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Check payment and quantity validation
    function _checkMintAndIncrementNumMinted(uint256 quantity) internal returns (uint256) {
        uint256 newAmount = _numMinted + quantity;

        unchecked {
            _validatePayment(MINT_PRICE, quantity);
        }
        _validateTimestamp();

        // increment supply before minting
        _numMinted = uint64(newAmount);
        return newAmount;
    }

    function _validateTimestamp() internal view {
        if (block.timestamp > mintCloseTimestamp) {
            revert MintClosed();
        }
    }
}
