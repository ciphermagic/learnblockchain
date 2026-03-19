import { http, parseEther, parseGwei } from 'viem';
import { foundry } from 'viem/chains';
import { createPublicClient, createWalletClient } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { split, combine } from 'shamirs-secret-sharing';
import dotenv from 'dotenv';

dotenv.config();

/**
 * MPC (Multi-Party Computation) 交易签名工具
 *
 * 什么是 MPC 钱包?
 * - MPC (多方计算) 钱包是一种分布式密钥管理方案
 * - 将私钥分割成多个分片（shares）
 * - 需要收集一定数量的分片（阈值，threshold）才能恢复私钥
 *
 * 核心概念:
 * - Shamir's Secret Sharing (Shamir 秘密共享)
 *   - 由 Adi Shamir 于 1979 年发明
 *   - 基于多项式插值的数学原理
 *   - 可以将秘密分割成 N 份，只需 K 份即可恢复
 *
 * 优势:
 * - 无需完全信任单个实体
 * - 提高安全性（单点故障被消除）
 * - 支持多方授权
 * - 灵活的门限设置（3-of-5, 2-of-3 等）
 *
 * 本脚本演示:
 * - 如何将私钥分割成分片
 * - 如何从部分分片恢复私钥
 * - 如何使用恢复的私钥进行签名交易
 */

// 生成私钥分片
/**
 * 使用 Shamir's Secret Sharing 将私钥分割成多个分片
 * @param {string} privateKey - 私钥（带 0x 前缀）
 * @param {number} totalShares - 总分片数量
 * @param {number} threshold - 恢复私钥所需的最少分片数
 * @returns {Buffer[]} 私钥分片数组
 *
 * 数学原理:
 * - 在有限域上创建一个 (threshold-1) 次多项式
 * - 令 f(0) = 私钥
 * - 计算 N 个点的值 (x, f(x))
 * - 每个分片就是一个 (x, f(x)) 点
 * - 任意 threshold 个点可以插值出多项式，从而得到私钥
 *
 * 示例:
 * - 私钥: 0xabc...
 * - totalShares: 5, threshold: 3
 * - 生成 5 个分片
 * - 任意 3 个分片可以恢复私钥
 * - 少于 3 个无法恢复
 */
function generatePrivateKeyShares(privateKey, totalShares, threshold) {
  // 将私钥转换为 Buffer（移除 0x 前缀）
  const privateKeyBuffer = Buffer.from(privateKey.slice(2), 'hex');

  // 使用 shamir-secret-sharing 库生成分片
  // split 函数将私钥分成 totalShares 份
  // threshold 指定恢复所需的最少份数
  const shares = split(privateKeyBuffer, {
    shares: totalShares, // 生成的总分片数
    threshold, // 恢复所需的最少分片数
  });
  return shares;
}

// 从分片恢复私钥
/**
 * 从给定的分片组合恢复私钥
 * @param {Buffer[]} shares - 私钥分片数组
 * @returns {string} 恢复的私钥（带 0x 前缀）
 *
 * 恢复原理:
 * - 使用 Lagrange 插值
 * - 在 threshold 个点上构造多项式
 * - 计算 f(0) 得到原始私钥
 *
 * 注意:
 * - 需要至少 threshold 个分片
 * - 分片的顺序不影响恢复结果
 */
function recoverPrivateKey(shares) {
  // 使用 combine 函数从分片恢复私钥
  const recoveredBuffer = combine(shares);
  return '0x' + recoveredBuffer.toString('hex');
}

// 验证分片
/**
 * 验证分片是否正确
 * @param {Buffer[]} shares - 私钥分片数组
 * @param {string} originalPrivateKey - 原始私钥
 * @param {number} threshold - 门限值
 * @returns {boolean} 验证是否成功
 *
 * 验证方法:
 * 1. 使用所有分片恢复私钥，应该与原始私钥一致
 * 2. 使用 threshold 个分片恢复，应该与原始私钥一致
 * 3. 使用少于 threshold 个分片，应该无法恢复（或得到错误结果）
 */
function verifyShares(shares, originalPrivateKey, threshold) {
  console.log('\n验证所有分片:');
  const allRecoveredKey = recoverPrivateKey(shares);
  console.log('原始私钥:', originalPrivateKey);
  console.log('使用所有分片恢复的私钥:', allRecoveredKey);
  console.log('是否一致:', originalPrivateKey === allRecoveredKey);

  console.log('\n验证部分分片:');
  const partialShares = shares.slice(0, threshold);
  const partialRecoveredKey = recoverPrivateKey(partialShares);
  console.log('使用部分分片恢复的私钥:', partialRecoveredKey);
  console.log('是否一致:', originalPrivateKey === partialRecoveredKey);

  return originalPrivateKey === partialRecoveredKey;
}

// 模拟 MPC 签名过程
/**
 * 使用 MPC 分片进行交易签名
 * @param {Buffer[]} shares - 私钥分片数组
 * @param {number} threshold - 门限值（需要的最少分片数）
 * @param {object} transaction - 交易参数对象
 * @returns {string} 已签名的交易数据
 *
 * MPC 签名流程:
 * 1. 收集足够的分片（>= threshold）
 * 2. 使用 combine 函数恢复私钥
 * 3. 从私钥创建账户对象
 * 4. 创建钱包客户端
 * 5. 对交易进行签名
 *
 * 实际 MPC 场景:
 * - 分片可以存储在不同的服务器/设备上
 * - 每方只持有自己的分片
 * - 需要多方协作才能签名
 * - 可以实现多签授权逻辑
 */
async function mpcSignTransaction(shares, threshold, transaction) {
  // 1. 恢复私钥
  // 从前 threshold 个分片恢复私钥
  // 实际应用中，分片可能来自不同的参与方
  const recoveredPrivateKey = recoverPrivateKey(shares.slice(0, threshold));
  console.log('已从 %d 个分片恢复私钥: %s...', threshold, recoveredPrivateKey.slice(0, 10));

  // 2. 从恢复的私钥创建账户
  const account = privateKeyToAccount(recoveredPrivateKey);

  // 3. 创建钱包客户端
  const walletClient = createWalletClient({
    account: account,
    chain: foundry,
    transport: http(process.env.RPC_URL),
  });

  // 4. 签名交易
  // 使用钱包客户端对交易进行签名
  // 返回已签名的交易数据（RLP 编码）
  const signedTx = await walletClient.signTransaction(transaction);

  return signedTx;
}

async function sendTransactionWithMPC() {
  try {
    // 1. 从环境变量获取私钥
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      throw new Error('请在 .env 文件中设置 PRIVATE_KEY');
    }
    console.log('原始私钥:', privateKey);

    // 2. 创建公共客户端
    const publicClient = createPublicClient({
      chain: foundry,
      transport: http(process.env.RPC_URL),
    });

    // 3. 从私钥创建账户
    const account = privateKeyToAccount(privateKey);
    const userAddress = account.address;
    console.log('账户地址:', userAddress);

    // 4. 生成私钥分片 (5个分片，需要3个分片才能恢复)
    const totalShares = 5;
    const threshold = 3;
    const shares = generatePrivateKeyShares(privateKey, totalShares, threshold);
    console.log(`生成了 ${totalShares} 个私钥分片，需要 ${threshold} 个分片才能恢复私钥`);

    // 验证分片恢复
    verifyShares(shares, privateKey, threshold);

    // 6. 检查网络状态
    const blockNumber = await publicClient.getBlockNumber();
    console.log('当前区块号:', blockNumber);

    // 7. 获取当前 gas 价格
    const gasPrice = await publicClient.getGasPrice();
    console.log('当前 gas 价格:', parseGwei(gasPrice.toString()));

    // 8. 查询余额
    const balance = await publicClient.getBalance({
      address: userAddress,
    });
    console.log('账户余额:', parseEther(balance.toString()));

    // 9. 查询 nonce
    const nonce = await publicClient.getTransactionCount({
      address: userAddress,
    });
    console.log('当前 Nonce:', nonce);

    // 10. 构建交易参数
    const txParams = {
      account: account,
      to: '0x01BF49D75f2b73A2FDEFa7664AEF22C86c5Be3df',
      value: parseEther('0.001'),
      chainId: foundry.id,
      type: 'eip1559',
      chain: foundry,
      maxFeePerGas: gasPrice * 2n,
      maxPriorityFeePerGas: parseGwei('1.5'),
      gas: 21000n,
      nonce: nonce,
    };

    // 12. 使用 MPC 签名交易
    console.log('开始 MPC 签名过程...');
    const signedTx = await mpcSignTransaction(shares, threshold, txParams);
    console.log('MPC 签名完成');

    // 13. 发送交易
    const txHash = await publicClient.sendRawTransaction({
      serializedTransaction: signedTx,
    });
    console.log('Transaction Hash:', txHash);

    // 14. 等待交易确认
    const receipt = await publicClient.waitForTransactionReceipt({
      hash: txHash,
    });
    console.log('交易状态:', receipt.status === 'success' ? '成功' : '失败');
    console.log('区块号:', receipt.blockNumber);
    console.log('Gas 使用量:', receipt.gasUsed.toString());

    return txHash;
  } catch (error) {
    console.error('错误:', error);
    if (error instanceof Error) {
      console.error('错误信息:', error.message);
    }
    if (error && typeof error === 'object' && 'details' in error) {
      console.error('错误详情:', error.details);
    }
    throw error;
  }
}

// 执行示例
sendTransactionWithMPC();
