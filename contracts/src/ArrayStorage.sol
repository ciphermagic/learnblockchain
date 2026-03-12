// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ArrayStorage - 数组存储示例合约
 * @notice 展示如何在合约中初始化数组数据
 * @dev 演示了：
 *      1. 使用结构体数组存储锁定信息
 *      2. 在构造函数中初始化数据
 *      3. 使用不同大小的整数类型优化存储
 *
 * 存储优化技巧：
 * - 使用 uint64 替代 uint256 存储时间戳，节省 Gas
 * - 使用 address(uint160(...)) 转换地址类型
 *
 * 部署命令：
 * forge create contracts/src/ArrayStorage.sol:ArrayStorage --rpc-url local --private-key <key> --broadcast
 */

// ============================================================
// 结构体定义
// ============================================================

/**
 * @title LockInfo - 锁定信息结构体
 * @dev 用于存储用户的锁定状态信息
 *
 * 存储优化：
 * - user: address (20 bytes)
 * - startTime: uint64 (8 bytes) - 使用较小整数类型
 * - amount: uint256 (32 bytes)
 *
 * 备注：Solidity 会自动打包相邻的变量
 *      user + startTime 被打包到一个 slot (20 + 8 = 28 bytes)
 *      amount 单独占用一个 slot
 */
struct LockInfo {
    address user;       // 锁定用户地址
    uint64 startTime;  // 锁定开始时间（使用 uint64 节省存储）
    uint256 amount;    // 锁定金额（单位：wei）
}

// ============================================================
// 合约主体
// ============================================================

/**
 * @title ArrayStorage
 * @dev 数组存储示例合约
 *
 * 功能：
 * - 初始化一个包含 11 个 LockInfo 的数组
 * - 每个 LockInfo 记录了测试用户的锁定信息
 *
 * 初始化数据说明：
 * - user: 地址 0x1 到 0xB
 * - startTime: 基于当前区块时间戳计算
 * - amount: 1e18 * (i + 1) = 1 到 11 ETH
 */
contract ArrayStorage {

    // 存储所有锁定信息的动态数组
    LockInfo[] private _locks;

    /**
     * @dev 构造函数，初始化测试数据
     *
     * 初始化 11 个 LockInfo：
     * - i = 0: user = 0x1, startTime = block.timestamp * 2 - 0, amount = 1e18
     * - i = 1: user = 0x2, startTime = block.timestamp * 2 - 1, amount = 2e18
     * - ...
     * - i = 10: user = 0xB, startTime = block.timestamp * 2 - 10, amount = 11e18
     *
     * 注意：
     * - 使用 address(uint160(i + 1)) 避免类型转换警告
     * - uint64 足够存储时间戳（到约 292 亿年）
     * - amount 使用 1e18 作为基本单位（1 ETH）
     */
    constructor() {
        for (uint256 i = 0; i < 11; i++) {
            // 构造地址：address(1) 到 address(11)
            address user = address(uint160(i + 1));

            // 构造时间戳：block.timestamp * 2 - i
            // 乘以 2 是为了演示，实际使用中不应这样做
            uint64 startTime = uint64(block.timestamp * 2 - i);

            // 构造金额：1e18 * (i + 1)，即 1 到 11 ETH
            uint256 amount = 1e18 * (i + 1);

            // 推入数组
            _locks.push(LockInfo(user, startTime, amount));
        }
    }

    /**
     * @notice 获取锁定信息数组长度
     * @return uint256 数组长度
     */
    function getLockLength() public view returns (uint256) {
        return _locks.length;
    }

    /**
     * @notice 获取指定索引的锁定信息
     * @param index 数组索引
     * @return LockInfo 锁定信息
     */
    function getLock(uint256 index) public view returns (LockInfo memory) {
        require(index < _locks.length, "Index out of bounds");
        return _locks[index];
    }
}
