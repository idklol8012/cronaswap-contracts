// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

// Allows anyone to collect a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // Returns the merkle root of the merkle tree containing account balances available to collect.
    function merkleRoot() external view returns (bytes32);
    // Returns true if the index has been marked collected.
    function isCollected(uint256 index) external view returns (bool);
    // Collect the given amount of the token to the given address. Reverts if the inputs are invalid.
    function collect(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;
    // Claim the token to the caller
    function claim() external;
    // Returns amount of token has been released.
    function claimable() external view returns (uint256);

    // This event is triggered whenever a call to #collect succeeds.
    event Collected(uint256 index, address account, uint256 amount);
    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(address account, uint256 amount);
}