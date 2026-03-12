// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

/**
 * @title BaseScript
 * @notice Foundry 部署脚本基类，提供统一的部署和配置管理功能
 * @dev 所有部署脚本都应继承此合约，以获得标准化的部署流程
 *
 * 主要功能：
 * 1. 自动识别网络环境（Anvil 本地网络 / Sepolia 测试网）
 * 2. 管理部署者私钥和地址
 * 3. 保存已部署合约地址到 JSON 文件
 * 4. 提供广播交易的修饰器
 */
contract BaseScript is Script {
    // ============ 状态变量 ============

    /// @notice 部署者私钥（仅在 Anvil 本地网络使用）
    uint256 internal deployerPrivateKey;

    /// @notice 部署者地址
    address internal deployer;

    /// @notice 标记是否设置了私钥（用于区分本地和测试网环境）
    bool internal isPrivateKeySet;

    // ============ 常量定义 ============

    /// @notice Anvil 本地测试网络的 Chain ID
    uint internal constant ANVIL = 31337;

    /// @notice Sepolia 测试网的 Chain ID
    uint internal constant SEPOLIA = 11155111;

    // ============ 构造函数 ============

    /**
     * @notice 初始化部署脚本，根据网络环境配置私钥
     * @param _privateKeyEnv 环境变量名称，用于读取私钥（仅 Anvil 需要）
     *
     * 逻辑说明：
     * - Anvil 本地网络：从环境变量读取私钥
     * - Sepolia 测试网：使用 Foundry 默认的签名方式（通过 --private-key 参数传入）
     */
    constructor(string memory _privateKeyEnv) {
        if (block.chainid == ANVIL) {
            // Anvil 本地网络：必须提供私钥环境变量
            require(bytes(_privateKeyEnv).length != 0, "private key env must set by anvil");
            isPrivateKeySet = true;
            deployerPrivateKey = vm.envUint(_privateKeyEnv);
        } else {
            // 其他网络：仅支持 Sepolia 测试网
            require(block.chainid == SEPOLIA, "only support sepolia");
        }
    }

    // ============ 公共函数 ============

    /**
     * @notice 保存已部署合约的地址到 JSON 文件
     * @param name 合约名称（用于生成文件名）
     * @param addr 合约地址
     *
     * 文件格式：deployments/<合约名>_<网络名>.json
     * JSON 内容：
     * {
     *   "address": "0x...",
     *   "deployer": "0x..." // 仅在设置了私钥时包含
     * }
     */
    function saveContract(string memory name, address addr) public {
        // 获取当前网络名称
        string memory networkName = getChain(block.chainid).name;

        // 构建 JSON 键名：<合约名>_<网络名>
        string memory key = string(abi.encodePacked(name, "_", networkName));

        // 序列化合约地址
        string memory json = vm.serializeAddress(key, "address", addr);

        // 如果设置了私钥，同时保存部署者地址
        if (isPrivateKeySet) {
            json = vm.serializeAddress(key, "deployer", deployer);
        }

        // 生成文件路径并写入 JSON
        string memory fileName = string.concat("deployments/", name, "_", networkName, ".json");
        vm.writeJson(json, fileName);
    }

    // ============ 修饰器 ============

    /**
     * @notice 广播交易修饰器，自动处理交易签名和广播
     * @dev 使用此修饰器的函数会自动：
     *      1. 开始广播交易
     *      2. 执行函数体
     *      3. 停止广播
     *
     * 行为说明：
     * - 如果设置了私钥（Anvil）：使用私钥签名并广播
     * - 如果未设置私钥（Sepolia）：使用 Foundry 默认签名方式
     */
    modifier broadcaster() {
        if (isPrivateKeySet) {
            // Anvil 本地网络：使用私钥签名
            vm.startBroadcast(deployerPrivateKey);
            deployer = vm.addr(deployerPrivateKey);
        } else {
            // Sepolia 测试网：使用默认签名方式
            vm.startBroadcast();
        }

        _; // 执行被修饰的函数

        vm.stopBroadcast();
    }
}
