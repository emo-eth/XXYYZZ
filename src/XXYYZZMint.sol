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
    }

    /**
     * @notice Set the mint close timestamp. onlyOwner.
     */
    function setMintCloseTimestamp(uint64 timestamp) external onlyOwner {
        if (timestamp > MAX_MINT_CLOSE_TIMESTAMP) {
            revert InvalidTimestamp();
        }
        mintCloseTimestamp = timestamp;
    }

    //////////
    // MINT //
    //////////

    /**
     * @notice Mint a token with a pseudorandom hex value.
     */
    function mint() public payable {
        _checkRandomMintAndIncrementNumMinted(1);

        // get pseudorandom hex id
        uint256 tokenId = _findAvailableHex();
        _mint(msg.sender, tokenId);
    }

    /**
     * @notice Mint a number of tokens with pseudorandom hex values.
     * @param quantity The number of tokens to mint
     */
    function mint(uint256 quantity) public payable {
        // check payment and quantity once
        _checkRandomMintAndIncrementNumMinted(quantity);
        for (uint256 i; i < quantity;) {
            // get pseudorandom hex id
            uint256 tokenId = _findAvailableHex();
            _mint(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    ///@dev Perform price and quantity validation as well as random mint cutoff validation
    function _checkRandomMintAndIncrementNumMinted(uint256 quantity) internal {
        uint256 newAmount = _checkMintAndIncrementNumMinted(quantity);
        // ensure a certain number are reserved for mints of specific IDs
        if (newAmount > RANDOM_MINT_CUTOFF) {
            revert RandomMintingEnded();
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
        uint256 newUserNumMinted;

        unchecked {
            _validatePayment(MINT_PRICE, quantity);
            newUserNumMinted = _getAux(msg.sender) + quantity;
        }
        if (newAmount > MAX_SUPPLY) {
            revert MaximumSupplyExceeded();
        }
        if (newUserNumMinted > MAX_MINTS_PER_WALLET) {
            revert MaximumMintsPerWalletExceeded();
        }

        // increment supply before minting
        unchecked {
            _numMinted = uint128(newAmount);
            _setAux(msg.sender, uint224(newUserNumMinted));
        }
        return newAmount;
    }
}
