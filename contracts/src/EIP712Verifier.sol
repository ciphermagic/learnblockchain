// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title EIP712Verifier - EIP-712 签名验证合约
 * @dev 演示如何使用 EIP-712 标准进行结构化数据签名验证
 *
 * EIP-712 是什么？
 * ==============
 * EIP-712 是 "Ethereum Typed Structured Data Signing" 标准
 * 允许用户签名结构化数据，而不是原始字节
 *
 * 解决的问题：
 * - 人类可读：签名数据以易读格式显示给用户
 * - 类型安全：防止因数据类型导致的签名验证失败
 * - 防重放：包含 domain 信息防止跨合约/链的重放攻击
 *
 * 签名流程：
 * 1. 定义数据结构（Send）
 * 2. 计算类型哈希（keccak256）
 * 3. 构建签名消息（EIP-712 domain）
 * 4. 签名者使用私钥签名
 * 5. 验证者使用 ECDSA.recover 验证签名
 *
 * 本合约示例：
 * - Send 数据结构：{to: address, value: uint256}
 * - 用户可签名授权向某地址转账
 * - 合约验证签名后执行转账
 */
contract EIP712Verifier is EIP712 {

    // 使用 ECDSA 库进行签名恢复
    using ECDSA for bytes32;

    // ============================================================
    // 数据结构定义
    // ============================================================

    /**
     * @title Send - 转账数据结构
     * @dev EIP-712 类型定义
     *
     * 字段：
     * - to: 收款人地址
     * - value: 转账金额（wei）
     */
    struct Send {
        address to;      // 收款人地址
        uint256 value;  // 转账金额
    }

    // ============================================================
    // 类型哈希常量
    // ============================================================

    /**
     * @notice Send 结构的类型哈希
     * @dev 用于 EIP-712 签名消息构建
     *
     * 计算方式：
     * keccak256("Send(address to,uint256 value)")
     *
     * 注意：类型名称必须与结构体名称完全一致
     */
    bytes32 public constant SEND_TYPEHASH = keccak256("Send(address to,uint256 value)");

    // ============================================================
    // 构造函数
    // ============================================================

    /**
     * @dev 构造函数，初始化 EIP-712 域名分隔符
     *
     * EIP-712 Domain Separator：
     * - name: 合约/应用名称（EIP712Verifier）
     * - version: 签名方案版本（1.0.0）
     * - chainId: 链 ID（自动从 EVM 获取）
     * - verifyingContract: 验证合约地址（自动设置）
     *
     * 作用：
     * - 防止跨链重放攻击
     * - 防止跨合约重放攻击
     */
    constructor() EIP712("EIP712Verifier", "1.0.0") {}

    // ============================================================
    // 核心函数
    // ============================================================

    /**
     * @notice 计算 Send 数据的 EIP-712 哈希
     * @param send 转账数据结构
     * @return bytes32 签名摘要
     *
     * 签名消息构建：
     * 1. 域名分离器（domain separator）
     * 2. 类型哈希（type hash）
     * 3. 编码数据（abi.encode）
     * 4. 最终哈希（keccak256）
     *
     * OpenZeppelin 实现使用 _hashTypedDataV4
     */
    function hashSend(Send memory send) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    SEND_TYPEHASH,
                    send.to,
                    send.value
                )
            )
        );
    }

    /**
     * @notice 验证 EIP-712 签名
     * @param signer 签名者地址（期望）
     * @param send 转账数据
     * @param signature 签名
     * @return bool 签名是否有效
     *
     * 验证流程：
     * 1. 计算数据哈希（hashSend）
     * 2. 从签名恢复签名者地址（ECDSA.recover）
     * 3. 比较恢复地址与期望地址
     *
     * 安全注意：
     * - 签名验证应在状态更新之前
     * - 考虑添加 nonce 防止重放攻击
     * - 考虑添加过期时间
     */
    function verify(
        address signer,
        Send memory send,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 digest = hashSend(send);
        return digest.recover(signature) == signer;
    }

    /**
     * @notice 通过 EIP-712 签名执行转账
     * @param signer 签名者地址
     * @param to 收款人地址
     * @param value 转账金额
     * @param signature 签名数据
     *
     * 完整流程：
     * 1. 验证签名是否有效
     * 2. 如果有效，执行 ETH 转账
     *
     * 安全注意：
     * - 此实现存在重入风险（先验证后转账）
     * - 实际使用应先更新状态再转账（Checks-Effects-Interactions）
     * - 建议添加 nonce 和过期时间防止重放
     *
     * 攻击场景示例：
     * 1. 签名者 A 授权向 B 转账 1 ETH
     * 2. 攻击者 C 拦截签名
     * 3. C 可以多次调用此函数（如果 nonce 未检查）
     */
    function sendByEIP712Signature(address signer, address to, uint256 value, bytes memory signature) public {
        // 验证签名
        require(verify(signer, Send({to: to, value: value}), signature), "Invalid signature");

        // 执行转账
        (bool success,) = to.call{value: value}("");
        require(success, "Transfer failed");
    }
}
