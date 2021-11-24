// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor {
    using SafeMath for uint256;

    address public immutable override token;
    bytes32 public immutable override merkleRoot;

    // duration in seconds for linear release
    uint256 public releaseDuration;
    // This is a packed array of booleans.
    mapping(uint256 => uint256) private collectedBitMap;
    // amount of token collected by user
    mapping(address => uint256) public collectedAmount;
    mapping(address => uint256) public collectedTime;
    // amount of token claimed by user
    mapping(address => uint256) public claimedAmount;

    constructor(address token_, bytes32 merkleRoot_, uint256 _releaseDuration) public {
        require(_releaseDuration != 0, 'MerkleDistributor: Duration should be greater than zero.');
        token = token_;
        merkleRoot = merkleRoot_;
        releaseDuration = _releaseDuration;
    }

    function isCollected(uint256 index) public view override returns (bool) {
        uint256 collectedWordIndex = index / 256;
        uint256 collectedBitIndex = index % 256;
        uint256 collectedWord = collectedBitMap[collectedWordIndex];
        uint256 mask = (1 << collectedBitIndex);
        return collectedWord & mask == mask;
    }

    function _setCollected(uint256 index) private {
        uint256 collectedWordIndex = index / 256;
        uint256 collectedBitIndex = index % 256;
        collectedBitMap[collectedWordIndex] = collectedBitMap[collectedWordIndex] | (1 << collectedBitIndex);
    }

    function collect(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(!isCollected(index), 'MerkleDistributor: Drop already collected.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it collected and send the token.
        _setCollected(index);
        collectedAmount[account] = amount;
        collectedTime[account] = block.timestamp;

        emit Collected(index, account, amount);
    }

    function claim() external override {
        uint256 _unclaimed = claimable().sub(claimedAmount[msg.sender]);
        if (_unclaimed > 0) {
            require(IERC20(token).transfer(msg.sender, _unclaimed), 'MerkleDistributor: Transfer failed.');
            claimedAmount[msg.sender] = claimedAmount[msg.sender].add(_unclaimed);

            emit Claimed(msg.sender, _unclaimed);
        }
    }

    function claimable() public override view returns (uint256) {
        if (collectedTime[msg.sender] == 0 || block.timestamp < collectedTime[msg.sender]) {
            return 0;
        } else if (block.timestamp >= collectedTime[msg.sender].add(releaseDuration)) {
            return collectedAmount[msg.sender];
        } else {
            return collectedAmount[msg.sender].mul(block.timestamp.sub(collectedTime[msg.sender])).div(releaseDuration);
        }
    }
}
