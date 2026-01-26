// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge create esRNT --rpc-url local --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
// 0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E
contract ArrayStorage {
    struct LockInfo {
        address user;
        uint64 startTime;
        uint256 amount;
    }

    LockInfo[] private _locks;

    constructor() {
        for (uint256 i = 0; i < 11; i++) {
            _locks.push(LockInfo(address(uint160(i + 1)), uint64(block.timestamp * 2 - i), 1e18 * (i + 1)));
        }
    }
}