/**
 * ETH 原生转账监听脚本
 *
 * 本脚本演示了如何实时监听以太坊网络上的 ETH 转账交易。
 * 与 ERC20 代币不同，ETH 转账不使用事件日志，而是通过分析区块中的交易来实现。
 *
 * 监听原理：
 * - ETH 转账是最基础的以太坊交易
 * - 当交易的 input 字段为 '0x'（空数据）且 value > 0 时，即为 ETH 转账
 * - 通过监听新区块，遍历其中的交易，筛选出 ETH 转账
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 RPC_URL（WebSocket 格式）
 * 2. pnpm tsx scripts/watchTransferEth.ts
 *
 * 支持的网络：
 * - foundry (本地测试网)
 * - sepolia (Sepolia 测试网)
 * - mainnet (以太坊主网)
 */

import { createPublicClient, formatEther, webSocket, publicActions } from 'viem';
import { foundry, sepolia } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

// ========== 网络配置 ==========
// Foundry 本地网络配置
const FOUNDRY = {
  chain: foundry,
  transport: webSocket(process.env.RPC_URL!),
};

// Sepolia 测试网配置
const SEPOLIA = {
  chain: sepolia,
  transport: webSocket(process.env.SEPOLIA_RPC_URL!),
};

/**
 * 主函数：启动 ETH 转账监听
 */
const main = async () => {
  // 创建公共客户端
  // 使用 publicActions 扩展添加额外功能
  const publicClient = createPublicClient(SEPOLIA).extend(publicActions);

  console.log('开始监听 ETH 转账交易...');
  console.log('网络:', SEPOLIA.chain.name);
  console.log('按 Ctrl+C 停止监听\n');

  // ========== 监听新区块 ==========
  // watchBlocks 会监听新区块的产生
  // 当新区块被挖掘时，触发回调函数
  const unwatch = publicClient.watchBlocks({
    // 获取完整交易信息
    includeTransactions: true,

    // 区块回调函数
    onBlock: async block => {
      // ========== 获取区块中的所有交易 ==========
      // 通过区块哈希获取区块详情
      // includeTransactions: true 会返回交易数组
      const blockWithTransactions = await publicClient.getBlock({
        blockHash: block.hash,
        includeTransactions: true,
      });

      // 如果没有交易，直接返回
      if (!blockWithTransactions.transactions || blockWithTransactions.transactions.length === 0) {
        return;
      }

      // ========== 遍历交易，筛选 ETH 转账 ==========
      for (const tx of blockWithTransactions.transactions) {
        // 判断是否为 ETH 转账的条件：
        // 1. input 为 '0x' 或空 - 表示没有调用任何合约
        // 2. value > 0 - 表示转账金额大于 0

        /**
         * 以太坊交易类型说明：
         * - 普通 ETH 转账：input = '0x', value > 0
         * - 合约调用：input != '0x', 有 data
         * - 合约部署：to = null, 有 data
         */
        if (tx.input === '0x' && tx.value > 0n) {
          console.log('\n========== 检测到 ETH 转账 ==========');
          console.log(`从: ${tx.from}`);
          console.log(`到: ${tx.to}`);
          console.log(`金额: ${formatEther(tx.value)} ETH`);
          console.log(`交易哈希: ${tx.hash}`);
          console.log(`区块号: ${block.number}`);
          console.log(`Gas 费用: ${formatEther(tx.gas * (tx.gasPrice || 0n))} ETH`);

          /**
           * 交易字段说明：
           * - from: 发送方地址
           * - to: 接收方地址（ETH 转账时必填）
           * - value: 转账金额（wei 格式）
           * - input: 调用数据（ETH 转账时为空 '0x'）
           * - gas: Gas 限制
           * - gasPrice: Gas 价格（Legacy 交易）
           * - maxFeePerGas: 最大 Gas 费用（EIP-1559）
           * - maxPriorityFeePerGas: 最大优先费（EIP-1559）
           * - nonce: 交易序号
           * - hash: 交易哈希
           * - blockHash: 所在区块哈希
           * - blockNumber: 所在区块号
           */
        }
      }
    },
  });

  console.log('监听已启动...\n');

  // ========== 处理程序退出 ==========
  // 监听 SIGINT（Ctrl+C）信号，优雅地停止监听
  process.on('SIGINT', () => {
    console.log('\n正在停止监听...');
    unwatch();  // 取消区块监听
    console.log('监听已停止');
    process.exit(0);
  });
};

/**
 * ETH vs ERC20 转账监听对比：
 *
 * ETH 转账监听：
 * - 原理：监听新区块，筛选 input='0x' 且 value>0 的交易
 * - 优点：不需要知道合约地址，所有 ETH 转账都能捕获
 * - 缺点：无法直接获取交易详情，需要额外查询
 *
 * ERC20 转账监听：
 * - 原理：监听 Transfer 事件日志
 * - 优点：事件包含详细的转账信息（from, to, value）
 * - 缺点：需要知道代币合约地址，只能监听特定代币
 *
 * 总结：
 * - 监听 ETH 用 watchBlocks
 * - 监听 ERC20 用 watchEvent (Transfer 事件)
 */

// 运行主函数
main().catch(error => {
  console.error('发生错误:', error);
  process.exit(1);
});
