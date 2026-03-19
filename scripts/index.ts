/**
 * Web3 交互示例脚本
 *
 * 本脚本是 viem 库的全面演示，展示了与以太坊交互的各种操作。
 * 包含：余额查询、ETH 转账、合约读取、合约写入、事件解析等
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 PRIVATE_KEY 和 RPC_URL
 * 2. pnpm tsx scripts/index.ts
 *
 * 前提条件：
 * - 需要部署 Counter 合约到本地网络
 * - 需要部署 ERC20 代币合约到本地网络
 */

import {
  createPublicClient,
  createWalletClient,
  formatEther,
  getContract,
  http,
  parseEther,
  parseGwei,
  publicActions,
  parseEventLogs,
} from 'viem';
import { foundry } from 'viem/chains';
import dotenv from 'dotenv';
import ERC20_ABI from '@/abis/MyERC20.json' with { type: 'json' };
import Counter_ABI from '@/abis/Counter.json' with { type: 'json' };
import { privateKeyToAccount } from 'viem/accounts';

dotenv.config();

// 合约地址配置（需要替换为实际部署的地址）
const COUNTER_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const ERC20_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

/**
 * 主函数：演示各种 Web3 交互操作
 */
const main = async () => {
  // ========== 步骤 1: 创建公共客户端 ==========
  // 公共客户端（Public Client）用于执行只读操作
  // 如：查询余额、读取合约状态、获取区块信息等
  //
  // 特性：
  // - 不需要私钥
  // - 可以任意数量
  // - 可以缓存复用
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  // ========== 步骤 2: 获取当前区块号 ==========
  const blockNumber = await publicClient.getBlockNumber();
  console.log(`当前区块号: ${blockNumber}`);

  // ========== 步骤 3: 查询地址余额 ==========
  // formatEther 将 wei 转换为 ETH（18 位精度）
  const tbalance = formatEther(
    await publicClient.getBalance({
      address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Anvil 默认账户 0
    }),
  );

  console.log(`账户 0xf39 的 ETH 余额: ${tbalance}`);

  // ========== 步骤 4: 创建钱包客户端 ==========
  // 钱包客户端（Wallet Client）用于执行需要签名钱包的操作
  // 如：发送交易、签名消息、部署合约等
  const account = privateKeyToAccount(process.env.PRIVATE_KEY! as `0x${string}`);

  const walletClient = createWalletClient({
    account,
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  // 获取钱包地址
  const address = await walletClient.getAddresses();
  console.log(`钱包地址: ${address}`);

  // ========== 步骤 5: 发送 ETH 转账（方式 1 - 基础版） ==========
  // 使用默认参数：自动估算 gas、使用当前 gas 价格
  const hash1 = await walletClient.sendTransaction({
    account,
    to: '0x639fa6c336035067a51872fa1db85a031d23f441',
    value: parseEther('300'), // 发送 300 ETH
  });

  console.log(`方式 1 - 默认参数的转账交易哈希: ${hash1}`);

  /**
   * sendTransaction 参数说明：
   * - account: 发送方账户
   * - to: 接收方地址
   * - value: 转账金额（wei 格式）
   * - gas: Gas 限制（可选，默认自动估算）
   * - maxFeePerGas: EIP-1559 最大费用（可选）
   * - maxPriorityFeePerGas: EIP-1559 优先费（可选）
   * - nonce: 交易序号（可选，默认自动获取）
   */

  // ========== 步骤 6: 发送 ETH 转账（方式 2 - 自定义参数） ==========
  // 手动指定 gas 和费用参数
  const hash2 = await walletClient.sendTransaction({
    account,
    gas: 21000n, // ETH 转账固定 gas 消耗
    maxFeePerGas: parseGwei('20'), // 最大每单位 gas 费用
    maxPriorityFeePerGas: parseGwei('2'), // 给矿工/验证者的优先费
    to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    value: parseEther('1'),
    // nonce: 1, // 可选，手动指定 nonce
  });

  console.log(`方式 2 - 自定义参数的转账交易哈希: ${hash2}`);

  // ========== 步骤 7: 创建 ERC20 合约实例 ==========
  // 使用 getContract 创建合约实例
  // 这提供了一种更方便的合约交互方式
  const erc20Contract = getContract({
    address: ERC20_ADDRESS,
    abi: ERC20_ABI,
    client: {
      public: publicClient,   // 只读操作
      wallet: walletClient,    // 写操作
    },
  });

  // ========== 步骤 8: 读取 ERC20 余额（方法 1） ==========
  // 使用合约实例的 read 方法
  const balance1 = formatEther(BigInt((await erc20Contract.read.balanceOf([address.toString()])) as string));
  console.log(`方法 1 - 地址 ${address.toString()} 的 ERC20 余额: ${balance1}`);

  // ========== 步骤 9: 读取 ERC20 余额（方法 2） ==========
  // 使用 publicClient.readContract 直接读取
  const balance = formatEther(
    BigInt(
      (await publicClient.readContract({
        address: ERC20_ADDRESS,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [address.toString()],
      })) as string,
    ),
  );
  console.log(`方法 2 - 地址 ${address.toString()} 的 ERC20 余额: ${balance}`);

  // ========== 步骤 10: 创建 Counter 合约实例 ==========
  const counterContract = getContract({
    address: COUNTER_ADDRESS,
    abi: Counter_ABI,
    client: {
      public: publicClient,
      wallet: walletClient,
    },
  });

  // ========== 步骤 11: 写入合约（方法 1） ==========
  // 使用合约实例的 write 方法
  // 这会自动处理签名、发送、nonce 等
  const incrementHash = await counterContract.write.increment();
  console.log(`调用 increment 方法的交易哈希: ${incrementHash}`);

  // 读取合约数据验证
  const number1 = await counterContract.read.number([]);
  console.log(`Counter 当前的 number 值: ${number1}`);

  // ========== 步骤 12: 写入合约（方法 2） ==========
  // 使用 walletClient.writeContract 直接写入
  await walletClient.writeContract({
    address: COUNTER_ADDRESS,
    abi: Counter_ABI,
    functionName: 'increment',
    args: [],
  });

  const number2 = await counterContract.read.number([]);
  console.log(`再次调用后的 number 值: ${number2}`);

  // ========== 步骤 13: ERC20 转账 ==========
  // 调用 ERC20 的 transfer 函数进行代币转账
  const erc20TransferHash = await erc20Contract.write.transfer([
    '0x01BF49D75f2b73A2FDEFa7664AEF22C86c5Be3df',
    parseEther('1'), // 转账 1 代币
  ]);
  console.log(`ERC20 转账交易哈希: ${erc20TransferHash}`);

  // ========== 步骤 14: 等待交易确认 ==========
  // waitForTransactionReceipt 等待交易被确认并返回收据
  const receipt = await publicClient.waitForTransactionReceipt({ hash: erc20TransferHash });
  console.log(`交易状态: ${receipt.status === 'success' ? '✅ 成功' : '❌ 失败'}`);

  // ========== 步骤 15: 解析事件日志 ==========
  // parseEventLogs 用于解析交易中的事件日志
  // 这对于了解交易执行结果非常有用
  const transferLogs = parseEventLogs({
    abi: ERC20_ABI,
    eventName: 'Transfer',
    logs: receipt.logs,
  });

  // 遍历解析后的事件
  for (const log of transferLogs) {
    const eventLog = log as unknown as { eventName: string; args: { from: string; to: string; value: bigint } };
    if (eventLog.eventName === 'Transfer') {
      console.log('\n========== 转账事件详情 ==========');
      console.log(`从: ${eventLog.args.from}`);
      console.log(`到: ${eventLog.args.to}`);
      console.log(`金额: ${formatEther(eventLog.args.value)}`);
    }
  }

  /**
   * 常见错误处理：
   *
   * 1. INSUFFICIENT_FUNDS
   *    - 原因：账户余额不足
   *    - 解决：充值或使用余额足够的账户
   *
   * 2. NONCE_TOO_LOW
   *    - 原因：nonce 已被使用
   *    - 解决：使用正确的 nonce 或等待交易确认
   *
   * 3. GAS_LIMIT_TOO_LOW
   *    - 原因：估算的 gas 不足
   *    - 解决：手动设置更高的 gas 限制
   *
   * 4. REPLACED
   *    - 原因：相同 nonce 的交易被替换
   *    - 解决：使用加速或取消功能
   */
};

/**
 * viem 客户端架构说明：
 *
 * ┌─────────────────────────────────────────────┐
 * │                  Client                     │
 * ├─────────────────────────────────────────────┤
 * │  Public Client (只读)                        │
 * │  ├── getBalance()                          │
 * │  ├── getBlockNumber()                      │
 * │  ├── readContract()                        │
 * │  ├── estimateGas()                         │
 * │  └── waitForTransactionReceipt()           │
 * ├─────────────────────────────────────────────┤
 * │  Wallet Client (读写)                       │
 * │  ├── sendTransaction()                     │
 * │  ├── writeContract()                       │
 * │  ├── signMessage()                         │
 * │  └── signTypedData()                       │
 * └─────────────────────────────────────────────┘
 */

// 运行主函数
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(error => {
    console.error('发生错误:', error);
    process.exit(1);
  });
}
