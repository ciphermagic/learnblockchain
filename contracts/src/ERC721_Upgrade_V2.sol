// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721_Upgrade} from "./ERC721_Upgrade.sol";

/**
 * @title ERC721_Upgrade_V2
 * @notice ERC721可升级合约的V2版本，演示合约升级
 * @dev 核心改进：
 *      1. 新增状态变量：version（版本号）
 *      2. 新增函数：getVersion()（查询版本）
 *      3. 新增初始化函数：initializeV2()（升级后初始化新变量）
 *
 *      升级流程：
 *      1. 部署ERC721_Upgrade_V2合约（新实现合约）
 *      2. owner调用代理合约的upgradeTo(v2Address)
 *      3. owner调用initializeV2()初始化新的version变量
 *      4. 升级完成，代理合约现在使用V2的逻辑
 *
 *      存储布局兼容性：
 *      - V1存储：ERC721状态 + Ownable状态
 *      - V2存储：V1存储 + version变量
 *      - 新变量追加在末尾，不影响原有存储布局
 *      - 符合OpenZeppelin的升级安全规范
 *
 *      继承关系：
 *      - 继承ERC721_Upgrade（V1合约）
 *      - 保留V1的所有功能（initialize、mint、_authorizeUpgrade）
 *      - 新增V2特有的功能
 *
 *      安全考虑：
 *      - initializeV2()使用onlyOwner修饰，防止未授权调用
 *      - 没有使用initializer修饰符，因为这不是首次初始化
 *      - version变量可以多次设置（如果需要限制，应添加标志位）
 *
 *      使用场景：
 *      - 演示UUPS代理模式的升级机制
 *      - 展示如何安全地添加新状态变量
 *      - 学习升级后的初始化模式
 */
contract ERC721_Upgrade_V2 is ERC721_Upgrade {
    /// @notice 版本号，用于标识当前合约版本
    /// @dev 新增的状态变量，追加在V1存储布局之后
    uint256 public version;

    /**
     * @notice 查询合约版本号
     * @return 当前版本号
     * @dev 简单的getter函数，演示V2新增功能
     */
    function getVersion() public view returns (uint256) {
        return version;
    }

    /**
     * @notice 初始化V2版本的新变量
     * @param _version 要设置的版本号
     * @dev 权限控制：只有owner可以调用
     *
     *      调用时机：
     *      - 在升级到V2后立即调用
     *      - 用于初始化新增的version变量
     *
     *      注意事项：
     *      - 没有使用initializer修饰符，因为这不是首次初始化
     *      - 可以多次调用（如果需要限制，应添加initialized标志）
     *      - 实际项目中可能需要更严格的初始化控制
     *
     *      最佳实践：
     *      - 升级后的初始化函数应该有明确的命名（如initializeV2）
     *      - 应该添加防重入初始化的机制
     *      - 应该在升级脚本中自动调用
     */
    function initializeV2(uint256 _version) public onlyOwner {
        version = _version;
    }
}