/**
 * build_raw_tx.ts - 原生交易构建与发送示例
 *
 * 本脚本演示如何使用 viem 构建和发送原生 ETH 转账交易
 * 支持两种发送方式：
 * 1. 使用 WalletClient 直接发送交易
 * 2. 签名后使用 PublicClient 发送原始交易
 *
 * 核心概念：
 * - PrivateKeyAccount: 从私钥推导的账户对象，用于签名交易
 * - PublicClient: 公共客户端，用于读取链上数据（余额、nonce、gas价格等）
 * - WalletClient: 钱包客户端，用于签名和发送交易
 * - EIP-1559: 伦敦升级后的交易类型，支持动态 Gas 费用
 *
 * 使用方法：
 * 1. 在 .env 文件中设置 PRIVATE_KEY 和 RPC_URL
 * 2. 运行: pnpm tsx scripts/build_raw_tx.ts
 */

import { createWalletClient, http, parseEther, parseGwei, type Hash, type TransactionReceipt } from 'viem';
import { prepareTransactionRequest } from 'viem/actions';
import { privateKeyToAccount, type PrivateKeyAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';
import { createPublicClient, type PublicClient, type WalletClient } from 'viem';
import dotenv from 'dotenv';

// 加载环境变量配置文件
dotenv.config();

/**
 * 发送原生 ETH 转账交易的示例函数
 *
 * 交易流程：
 * 1. 从私钥创建账户对象
 * 2. 创建 PublicClient 和 WalletClient
 * 3. 查询链上状态（区块高度、Gas 价格、余额、Nonce）
 * 4. 构建交易参数（EIP-1559 格式）
 * 5. 准备交易（自动补充缺失参数）
 * 6. 签名并发送交易
 * 7. 等待交易确认并获取收据
 */
async function sendTransactionExample() {
  try {
    // ==================== 步骤 1: 账户初始化 ====================
    // 从环境变量获取私钥（注意：私钥必须以 0x 开头）
    const privateKey = process.env.PRIVATE_KEY as `0x${string}`;
    if (!privateKey) {
      throw new Error('请在 .env 文件中设置 PRIVATE_KEY');
    }

    // 使用私钥推导以太坊账户
    // privateKeyToAccount 会从私钥计算出对应的公钥和地址
    // 这是一个非确定性推导，每次使用相同私钥会得到相同的地址
    const account: PrivateKeyAccount = privateKeyToAccount(privateKey);
    const userAddress = account.address;
    console.log('📍 账户地址:', userAddress);

    // ==================== 步骤 2: 创建客户端 ====================
    // PublicClient 用于与区块链进行只读交互
    // - 查询账户余额
    // - 获取当前区块号
    // - 查询交易计数（nonce）
    // - 获取 Gas 价格
    // - 发送已签名交易（broadcast transaction）
    const publicClient: PublicClient = createPublicClient({
      chain: foundry, // 使用 Foundry 本地测试网络
      transport: http(process.env.RPC_URL), // RPC 端点
    });

    // ==================== 步骤 3: 查询链上状态 ====================

    // 3.1 获取当前区块号 - 用于确认网络连接正常
    const blockNumber = await publicClient.getBlockNumber();
    console.log('🔗 当前区块号:', blockNumber);

    // 3.2 获取当前 Gas 价格（基础费用）
    // 在 EIP-1559 中，Gas 价格由 baseFeePerGas + priorityFeePerGas 组成
    // baseFeePerGas 由网络根据拥堵程度自动调整
    const gasPrice = await publicClient.getGasPrice();
    console.log('⛽ 当前 Gas 价格:', parseGwei(gasPrice.toString()), 'Gwei');

    // 3.3 查询账户 ETH 余额
    // ETH 余额以 Wei 为单位返回，需要使用 parseEther 转换为 ETH 单位
    const balance = await publicClient.getBalance({
      address: userAddress,
    });
    console.log('💰 账户余额:', parseEther(balance.toString()), 'ETH');

    // 3.4 查询交易计数器（Nonce）
    // Nonce 表示该账户已发送的交易数量
    // 同一账户的下一笔交易的 nonce 必须等于当前 nonce
    // 这确保了交易的顺序性，防止双重支付
    const nonce = await publicClient.getTransactionCount({
      address: userAddress,
    });
    console.log('🔢 当前 Nonce:', nonce);

    // ==================== 步骤 4: 构建交易参数 ====================
    /**
     * EIP-1559 交易类型详解：
     *
     * maxFeePerGas: 用户愿意为每单位 Gas 支付的最高费用
     *   = baseFeePerGas (网络自动计算) + maxPriorityFeePerGas (给矿工的小费)
     *   实际费用 = min(maxFeePerGas, baseFeePerGas + actualPriorityFee)
     *
     * maxPriorityFeePerGas: 给矿工/验证者的最大小费
     *   这是用户愿意额外支付的费用，用于激励优先打包交易
     *   设置较高的小费可以加快交易确认速度
     *
     * gas: Gas 限制
     *   - ETH 转账基本费用: 21000 Gas
     *   - 合约交互: 根据合约复杂度而定
     *   - 设置过低会导致交易失败（Out of Gas）
     *   - 设置过高会导致多余的 Gas 退还
     *
     * nonce: 交易序号
     *   确保同一账户的交易按顺序执行
     *   可以通过设置相同的 nonce 来替换_pending_状态的交易
     */
    const txParams = {
      account: account, // 交易发送方
      to: '0x01BF49D75f2b73A2FDEFa7664AEF22C86c5Be3df' as `0x${string}`, // 目标收款地址
      value: parseEther('0.001'), // 转账金额（单位: ETH）
      chainId: foundry.id, // 链 ID（1 = Ethereum Mainnet, 11155111 = Sepolia）
      type: 'eip1559' as const, // 使用 EIP-1559 交易类型
      chain: foundry, // 链配置对象

      // EIP-1559 特有参数
      maxFeePerGas: gasPrice * 2n, // 最大 Gas 费用（设为当前 Gas 价格的 2 倍）
      maxPriorityFeePerGas: parseGwei('1.5'), // 最大优先费（给矿工的小费）
      gas: 21000n, // Gas 限制（ETH 转账固定 21000）
      nonce: nonce, // 交易计数器
    };

    // ==================== 步骤 5: 准备交易 ====================
    /**
     * prepareTransactionRequest 会自动：
     * - 估算 Gas 使用量（如果未设置 gas 参数）
     * - 补充缺失的交易参数
     * - 验证交易参数的有效性
     * - 根据当前网络状况调整 Gas 参数
     */
    const preparedTx = await prepareTransactionRequest(publicClient, txParams);
    console.log('✅ 准备后的交易参数:', {
      ...preparedTx,
      maxFeePerGas: parseGwei(preparedTx.maxFeePerGas.toString()),
      maxPriorityFeePerGas: parseGwei(preparedTx.maxPriorityFeePerGas.toString()),
    });

    // ==================== 步骤 6: 创建钱包客户端 ====================
    /**
     * WalletClient vs PublicClient 的区别：
     *
     * PublicClient:
     * - 只读操作，不需要私钥
     * - 查询余额、块信息、交易收据等
     * - 广播已签名交易
     *
     * WalletClient:
     * - 需要账户（私钥推导或外部连接的钱包）
     * - 签名交易
     * - 发送交易
     * - 部署合约
     */
    const walletClient: WalletClient = createWalletClient({
      account: account, // 绑定了账户，可以自动签名
      chain: foundry,
      transport: http(process.env.RPC_URL),
    });

    // ==================== 步骤 7: 发送交易 ====================
    /**
     * 发送交易的两种方式：
     *
     * 方式 1: 直接发送（推荐）
     * - WalletClient.sendTransaction() 会自动签名并发送
     * - 适合大多数场景
     *
     * 方式 2: 手动签名后发送
     * - 先用 WalletClient.signTransaction() 签名
     * - 再用 PublicClient.sendRawTransaction() 广播
     * - 适合需要离线签名、多个签名者等复杂场景
     */

    // 方式 1：使用 WalletClient 直接发送交易
    // 内部会自动使用 account 对交易进行签名
    const txHash1 = await walletClient.sendTransaction(preparedTx);
    console.log('📤 交易已发送（方式1）');
    console.log('🔖 交易哈希:', txHash1);

    // 等待方式1确认，再获取新的 nonce
    await publicClient.waitForTransactionReceipt({ hash: txHash1 });

    // 重新获取 nonce（此时 nonce 已更新）
    const newNonce = await publicClient.getTransactionCount({ address: userAddress });

    const preparedTx2 = await prepareTransactionRequest(publicClient, {
      ...preparedTx,
      nonce: newNonce,
    });

    // 方式 2：手动签名后发送
    // 步骤 1: 使用钱包客户端对交易进行签名
    // 签名过程：使用私钥对交易数据进行哈希运算
    const signedTx = await walletClient.signTransaction(preparedTx2);
    console.log('✍️ 已签名交易:', signedTx);

    // 步骤 2: 使用公共客户端发送已签名交易
    // sendRawTransaction 相当于 eth_sendRawTransaction RPC 方法
    // 这是将交易广播到网络的方式
    const txHash2 = await publicClient.sendRawTransaction({
      serializedTransaction: signedTx,
    });
    console.log('📤 交易已广播（方式2）');
    console.log('🔖 交易哈希:', txHash2);

    // ==================== 步骤 8: 等待交易确认 ====================
    /**
     * waitForTransactionReceipt 会：
     * 1. 轮询网络，等待交易被打包
     * 2. 返回交易收据（Receipt）
     *
     * 收据包含：
     * - status: 交易成功或失败
     * - blockNumber: 交易被包含的区块号
     * - gasUsed: 实际使用的 Gas 数量
     * - transactionIndex: 交易在区块中的索引位置
     * - logs: 交易产生的事件日志
     */
    console.log('方式一交易结果...');
    const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: txHash1 });
    console.log('🎉 交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
    console.log('📦 区块号:', receipt.blockNumber);
    console.log('⛽ Gas 使用量:', receipt.gasUsed.toString());

    console.log('方式二交易结果...');
    const receipt2: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: txHash2 });
    console.log('🎉 交易状态:', receipt2.status === 'success' ? '✅ 成功' : '❌ 失败');
    console.log('📦 区块号:', receipt2.blockNumber);
    console.log('⛽ Gas 使用量:', receipt2.gasUsed.toString());

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
sendTransactionExample();
