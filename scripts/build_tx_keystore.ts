/**
 * build_tx_keystore.ts - 使用 Keystore 文件发送交易示例
 *
 * 本脚本演示如何使用加密的 keystore 文件来签名和发送交易
 *
 * 🔐 什么是 Keystore？
 *
 * Keystore 是一种以太坊私钥的加密存储格式，常见于：
 * - Mist 钱包
 * - Geth 钱包
 * - Parity 钱包
 * - 其他以太坊客户端
 *
 * Keystore 文件的特点：
 * 1. 加密存储：私钥使用用户提供的密码进行加密
 * 2. JSON 格式：易于存储和传输
 * 3. 标准格式：遵循 Web3 钱包的通用标准
 * 4. 安全性：不暴露明文私钥
 *
 * 📋 Keystore 文件结构示例：
 * {
 *   "address": "abc123...",
 *   "crypto": {
 *     "cipher": "aes-128-ctr",
 *     "ciphertext": "encrypted-data...",
 *     "cipherparams": { "iv": "..." },
 *     "kdf": "scrypt",
 *     "kdfparams": { "dklen": 32, "n": 16384, "r": 8, "p": 1, "salt": "..." },
 *     "mac": "..."
 *   },
 *   "id": "uuid...",
 *   "version": 3
 * }
 *
 * 🔒 为什么使用 Keystore？
 *
 * 1. 安全性提升：
 *    - 不在代码中暴露明文私钥
 *    - 私钥在内存中解密，使用后可以清除
 *    - 攻击者即使获取文件也无法直接使用
 *
 * 2. 密钥管理：
 *    - 可以使用不同密码保护多个账户
 *    - 方便备份和迁移钱包
 *
 * 3. 生产环境：
 *    - 服务器部署时不需要硬编码私钥
 *    - 私钥可以从安全的密钥管理系统加载
 *
 * 📝 使用方法：
 * 1. 在 .env 文件中设置：
 *    - KEYSTORE_PATH: keystore 文件路径（如 ./keystore/UTC--2024-01-01--abc.json）
 *    - KEYSTORE_PASSWORD: 解密密码
 *    - RPC_URL: RPC 节点地址
 * 2. 运行: pnpm tsx scripts/build_tx_keystore.ts
 */

import { createWalletClient, http, parseEther, parseGwei, type Hash, type TransactionReceipt } from 'viem';
import { prepareTransactionRequest } from 'viem/actions';
import { foundry } from 'viem/chains';
import { createPublicClient, type PublicClient, type WalletClient } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { readFileSync } from 'fs';
import { join } from 'path';
import dotenv from 'dotenv';
// ethers.js 的 Wallet 类提供了 keystore 解密功能
import { Wallet } from '@ethersproject/wallet';

// 加载环境变量配置
dotenv.config();

/**
 * 使用 Keystore 文件发送交易的函数
 *
 * 完整流程：
 * 1. 读取 keystore 文件
 * 2. 使用密码解密 keystore 获取私钥
 * 3. 创建 viem 客户端
 * 4. 查询链上状态
 * 5. 构建、签名、发送交易
 */
async function sendTransactionWithKeystore(): Promise<Hash> {
  try {
    // ==================== 步骤 1: 获取配置 ====================
    // 从环境变量获取 keystore 文件路径和解密密码
    // 注意：这些敏感信息不应该提交到代码仓库！
    const keystorePath = process.env.KEYSTORE_PATH;
    const keystorePassword = process.env.KEYSTORE_PASSWORD;

    if (!keystorePath || !keystorePassword) {
      throw new Error('请在 .env 文件中设置 KEYSTORE_PATH 和 KEYSTORE_PASSWORD');
    }

    // ==================== 步骤 2: 读取 Keystore 文件 ====================
    /**
     * Keystore 文件读取说明：
     * - 使用 readFileSync 同步读取文件内容
     * - 文件内容是 JSON 字符串，包含加密的私钥信息
     * - 不要在日志中打印 keystore 内容，防止泄露
     */
    const keystoreContent = readFileSync(join(process.cwd(), keystorePath), 'utf-8');
    const keystore = JSON.parse(keystoreContent);
    console.log('📂 已读取 Keystore 文件:', keystorePath);

    // ==================== 步骤 3: 解密 Keystore ====================
    /**
     * Keystore 解密原理：
     * 1. Wallet.fromEncryptedJson() 使用密码配合 kdf（密钥派生函数）
     *    - 常用的 kdf 有 scrypt 和 pbkdf2
     *    - scrypt 更安全但计算更慢
     * 2. 通过 kdf 派生出的密钥来解密 ciphertext
     * 3. 解密后的数据包含原始私钥
     *
     * ⚠️ 安全性注意：
     * - 解密后的私钥存在于内存中
     * - 使用完毕后应该尽快清除内存中的私钥
     * - 不要将私钥打印到日志或保存到文件
     */
    const wallet = await Wallet.fromEncryptedJson(keystoreContent, keystorePassword);
    // 获取解密后的私钥（转换为 viem 格式）
    const privateKey = wallet.privateKey as `0x${string}`;
    console.log('🔓 Keystore 解密成功');

    // ==================== 步骤 4-5: 创建客户端 ====================
    /**
     * PublicClient vs WalletClient 的分工：
     * - PublicClient: 负责只读操作（查询余额、块信息等）
     * - WalletClient: 负责交易操作（需要账户）
     *
     * 注意：这里创建 WalletClient 时没有绑定账户
     * 因为我们稍后会从私钥创建账户并用于签名
     */
    const publicClient: PublicClient = createPublicClient({
      chain: foundry,
      transport: http(process.env.RPC_URL),
    });

    const walletClient: WalletClient = createWalletClient({
      chain: foundry,
      transport: http(process.env.RPC_URL),
    });

    // ==================== 步骤 6: 从私钥创建账户 ====================
    /**
     * privateKeyToAccount 的作用：
     * - 从私钥推导出完整的以太坊账户信息
     * - 包括：地址（address）、公钥（publicKey）等
     * - 这个推导是确定性的：相同私钥始终推导出相同地址
     *
     * ⚠️ 重要提示：
     * - 私钥应该被视为最高机密
     * - 切勿将私钥发送给任何人或保存到不安全的地方
     */
    const account = privateKeyToAccount(privateKey);
    const userAddress = account.address;
    console.log('📍 账户地址:', userAddress);

    // ==================== 步骤 7-10: 查询链上状态 ====================
    // 这些查询帮助我们了解当前网络状态和账户状态

    // 7. 查询当前区块高度
    const blockNumber = await publicClient.getBlockNumber();
    console.log('🔗 当前区块号:', blockNumber);

    // 8. 查询当前 Gas 价格
    // Gas 价格以 Wei 为单位，需要转换为 Gwei 显示
    const gasPrice = await publicClient.getGasPrice();
    console.log('⛽ 当前 Gas 价格:', parseGwei(gasPrice.toString()), 'Gwei');

    // 9. 查询账户 ETH 余额
    // ETH 余额也以 Wei 为单位，需要转换为 ETH 显示
    const balance = await publicClient.getBalance({
      address: userAddress,
    });
    console.log('💰 账户余额:', parseEther(balance.toString()), 'ETH');

    // 10. 查询账户 Nonce
    // Nonce 表示账户已发送的交易数量，用于确保交易顺序
    const nonce = await publicClient.getTransactionCount({
      address: userAddress,
    });
    console.log('🔢 当前 Nonce:', nonce);

    // ==================== 步骤 11: 构建交易参数 ====================
    /**
     * EIP-1559 交易参数详解：
     * - type: 'eip1559' 使用 EIP-1559 交易类型
     * - maxFeePerGas: 愿意支付的最高 Gas 价格
     * - maxPriorityFeePerGas: 给矿工的小费
     * - gas: 预估的 Gas 使用量（ETH 转账固定 21000）
     */
    const txParams = {
      account: account, // 发送方账户
      to: '0x01BF49D75f2b73A2FDEFa7664AEF22C86c5Be3df' as `0x${string}`, // 收款方地址
      value: parseEther('0.001'), // 转账金额（0.001 ETH）
      chainId: foundry.id, // 链 ID
      type: 'eip1559' as const, // EIP-1559 交易类型
      chain: foundry, // 链配置

      // EIP-1559 特有参数
      maxFeePerGas: gasPrice * 2n, // 最高 Gas 费用（当前价格的 2 倍）
      maxPriorityFeePerGas: parseGwei('1.5'), // 最大小费
      gas: 21000n, // Gas 限制
      nonce: nonce, // 交易计数器
    };

    // ==================== 步骤 12: 准备交易 ====================
    /**
     * prepareTransactionRequest 的作用：
     * - 验证交易参数的完整性
     * - 补充缺失的参数（如未指定 gas 时自动估算）
     * - 根据网络状态调整参数
     */
    const preparedTx = await prepareTransactionRequest(publicClient, txParams);
    console.log('✅ 交易参数准备完成:', {
      ...preparedTx,
      maxFeePerGas: parseGwei(preparedTx.maxFeePerGas.toString()),
      maxPriorityFeePerGas: parseGwei(preparedTx.maxPriorityFeePerGas.toString()),
    });

    // ==================== 步骤 13: 签名交易 ====================
    /**
     * 签名过程：
     * 1. 使用账户的私钥对交易数据进行哈希
     * 2. 使用 ECDSA 签名算法生成签名
     * 3. 签名包含：v, r, s 三个值
     *
     * 签名后的交易可以：
     * - 通过 eth_sendRawTransaction 广播
     * - 不需要私钥持有者在场（离线签名）
     */
    const signedTx = await walletClient.signTransaction(preparedTx);
    console.log('✍️ 交易已签名');
    console.log('📝 签名后的交易:', signedTx);

    // ==================== 步骤 14: 发送交易 ====================
    /**
     * 广播交易：
     * sendRawTransaction 相当于 eth_sendRawTransaction RPC 方法
     * 将已签名的交易发送到节点，节点验证签名后会广播到网络
     */
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedTx,
    });
    console.log('📤 交易已广播');
    console.log('🔖 交易哈希:', txHash);

    // ==================== 步骤 15: 等待确认 ====================
    /**
     * 等待交易确认：
     * - waitForTransactionReceipt 会轮询节点直到交易被打包
     * - 返回交易收据，包含执行结果
     */
    const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log('🎉 交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
    console.log('📦 区块号:', receipt.blockNumber);
    console.log('⛽ Gas 使用量:', receipt.gasUsed.toString());

    return txHash;
  } catch (error) {
    console.error('❌ 错误:', error);
    if (error instanceof Error) {
      console.error('📝 错误信息:', error.message);
    }
    if (error && typeof error === 'object' && 'details' in error) {
      console.error('🔍 错误详情:', error.details);
    }
    throw error;
  }
}

// 执行示例
sendTransactionWithKeystore();
