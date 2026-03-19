/**
 * 交易模拟器使用示例
 *
 * 什么是交易模拟?
 * - 在不实际执行交易的情况下预测交易结果
 * - 用于估算 Gas、预览转账结果、检测交易风险
 *
 * 模拟器功能:
 * - 估算交易 Gas 消耗量
 * - 追踪 ETH/ERC20/ERC721 转账
 * - 分析交易对状态的影响
 * - 检测交易是否会 revert
 *
 * 模拟方法对比:
 * 1. 基础模拟: 使用快照 + 估算 Gas
 * 2. trace_transaction: Parity/Erigon 风格追踪
 * 3. debug_traceTransaction: Geth 风格调试追踪
 * 4. debug_traceCall: 模拟调用（不执行交易）
 *
 * 使用场景:
 * - DApp: 用户发送交易前预览结果
 * - 钱包: 交易确认前显示详细信息
 * - 机器人: 检测有利可图的套利机会
 * - 开发者: 调试合约交互
 */
import { TransactionSimulator } from './transaction_simulator.js';
import { parseEther, parseAbi, encodeFunctionData, type Address } from 'viem';
import dotenv from 'dotenv';

dotenv.config();

async function runExamples() {
  // 创建交易模拟器实例
  // 参数: RPC URL (从环境变量读取)
  const simulator = new TransactionSimulator(process.env.RPC_URL!);

  console.log('🔬 交易模拟器示例\n');
  console.log('='.repeat(60));

  // ============================================================
  // 示例 1: 模拟简单的 ETH 转账
  // ============================================================
  console.log('\n📌 示例 1: 模拟 ETH 转账\n');
  console.log('说明: 模拟最基础的 ETH 转账交易\n');

  // 模拟 ETH 转账
  // 参数说明:
  // - from: 发送方地址 (Anvil 默认账户 #0)
  // - to: 接收方地址 (Anvil 默认账户 #1)
  // - value: 转账金额 (1.5 ETH)
  const ethTransferResult = await simulator.simulateTransactionBasic({
    from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as Address, // Anvil 默认账户 0
    to: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8' as Address, // Anvil 默认账户 1
    value: parseEther('1.5'), // 发送 1.5 ETH
  });

  if (ethTransferResult.success) {
    console.log(`✅ 模拟成功！Gas 使用: ${ethTransferResult.gasUsed}`);
    simulator.formatTransfers(ethTransferResult.transfers);
  } else {
    console.error(`❌ 模拟失败: ${ethTransferResult.error}`);
  }

  console.log('='.repeat(60));

  // ============================================================
  // 示例 2: 模拟 ERC20 转账
  // ============================================================
  console.log('\n📌 示例 2: 模拟 ERC20 转账\n');
  console.log('说明: 模拟调用 ERC20 合约的 transfer 函数\n');
  console.log('💡 提示: 请先部署 ERC20 合约到 Anvil，然后替换下面的合约地址\n');

  // ERC20 合约地址 - 需要替换为实际部署的合约地址
  const erc20Address = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9' as Address;

  // 编码 transfer 函数调用
  const transferData = encodeFunctionData({
    abi: parseAbi(['function transfer(address to, uint256 amount) returns (bool)']),
    functionName: 'transfer',
    args: [
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8' as Address, // 接收地址
      parseEther('100'), // 转账 100 代币
    ],
  });

  // 注释掉实际调用，因为需要先部署合约
  const erc20TransferResult = await simulator.simulateTransactionBasic({
    from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as Address,
    to: erc20Address,
    data: transferData,
  });

  if (erc20TransferResult.success) {
    console.log(`✅ 模拟成功！Gas 使用: ${erc20TransferResult.gasUsed}`);
    simulator.formatTransfers(erc20TransferResult.transfers);
  } else {
    console.error(`❌ 模拟失败: ${erc20TransferResult.error}`);
  }

  console.log('='.repeat(60));

  // ============================================================
  // 示例 3: 模拟 存款到 tokenbank 合约
  // ============================================================
  console.log('\n📌 示例 3: 模拟 ETH 存款到合约\n');
  console.log('说明: 模拟调用合约的 depositEth 函数，同时转账 ETH\n');
  console.log('💡 提示: 请先部署 TokenBank 合约到 Anvil，然后替换下面的合约地址\n');

  const OPS6_ADDRESS = '0xD0B50F190F097D2E2E3136B6105923d1EEf67569' as Address;
  const tokenbank_address = '0xD0DB636309D53423B6Bb7A3B318Aaee7CC9CB41A' as Address;

  const depositEthData = encodeFunctionData({
    abi: parseAbi(['function depositEth(uint256 amount)']),
    functionName: 'depositEth',
    args: [
      parseEther('1.5'), // 转账 1.5 ETH
    ],
  });

  const depositEthResult = await simulator.simulateTransactionBasic({
    from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as Address,
    to: tokenbank_address,
    data: depositEthData,
    value: parseEther('1.5'),
  });

  if (depositEthResult.success) {
    console.log(`✅ 模拟成功！Gas 使用: ${depositEthResult.gasUsed}`);
    simulator.formatTransfers(depositEthResult.transfers);
  } else {
    console.error(`❌ 模拟失败: ${depositEthResult.error}`);
  }

  console.log('='.repeat(60));

  // ============================================================
  // 示例 4: 模拟 ERC20 存款到 tokenbank 合约
  // ============================================================
  console.log('\n📌 示例 4: 模拟 ERC20 存款到合约\n');
  console.log('说明: 先 approve 授权，再调用 deposit 函数存入 ERC20 代币\n');
  console.log('注意: 这是一个两笔交易的操作流程\n');
  // console.log('💡 提示: 请先部署 ERC20 合约到 Anvil，然后替换下面的合约地址\n');

  const approveData = encodeFunctionData({
    abi: parseAbi(['function approve(address spender, uint256 amount)']),
    functionName: 'approve',
    args: [tokenbank_address, parseEther('1.5')],
  });

  await simulator.simulateTransactionBasic({
    from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as Address,
    to: OPS6_ADDRESS,
    data: approveData,
    value: 0n,
  });

  const depositErc20Data = encodeFunctionData({
    abi: parseAbi(['function deposit(uint256 amount)']),
    functionName: 'deposit',
    args: [parseEther('1')],
  });

  const depositErc20Result = await simulator.simulateTransactionBasic({
    from: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' as Address,
    to: tokenbank_address,
    data: depositErc20Data,
  });

  if (depositErc20Result.success) {
    console.log(`✅ 模拟执行成功！ Gas 使用: ${depositErc20Result.gasUsed}`);
    simulator.formatTransfers(depositErc20Result.transfers);
  } else {
    console.error(`❌ 模拟执行失败: ${depositErc20Result.error}`);
  }

  console.log('='.repeat(60));
}

// 运行示例
runExamples().catch(error => {
  console.error('发生错误:', error);
  process.exit(1);
});
