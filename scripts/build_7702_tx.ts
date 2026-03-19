/**
 * EIP-7702 授权交易演示脚本（第三方执行）
 *
 * 本脚本演示了 EIP-7702 的核心功能：
 * - 将 EOA（外部拥有账户）临时授权为代理合约
 * - 第三方可以代表 EOA 执行交易（类似 meta-transaction）
 *
 * EIP-7702 工作原理：
 * 1. EOA 签署一个授权消息，授权某个合约代码
 * 2. 授权后，该 EOA 在交易执行期间具有合约代码
 * 3. 第三方可以调用该 EOA 地址上的合约代码
 * 4. 交易完成后，EIP-7702 自动清除授权（恢复为 EOA）
 *
 * 使用方法:
 * 1. 启动本地 Foundry 网络: anvil
 * 2. 部署 SimpleDelegate、ERC20、TokenBank 合约
 * 3. 配置环境变量
 * 4. pnpm tsx scripts/build_7702_tx.ts
 *
 * ⚠️ 注意：EIP-7702 仍处于草案阶段，可能会有变化
 */

import { createPublicClient, createWalletClient, http, encodeFunctionData, getContract, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';
import type { TransactionReceipt } from 'viem';

import SimpleDelegateAbi from '@/abis/SimpleDelegate.json' with { type: 'json' };
import ERC20Abi from '@/abis/MyERC20.json' with { type: 'json' };
import TokenBankAbi from '@/abis/TokenBank.json' with { type: 'json' };

// ====== 账户配置 ======
// Alice: 初始 EOA，将被授权
const ALICE_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
// Bob: 第三方执行者，代表 Alice 发送交易
const BOB_PRIVATE_KEY = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';

// ====== 合约地址配置 ======
// SimpleDelegate: 代理执行合约
const SIMPLE_DELEGATE_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';
// ERC20: 测试代币合约
const ERC20_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
// TokenBank: 存款合约
const TOKENBANK_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';

// ====== 交易参数 ======
// 存款金额：1 代币（18 位精度）
const DEPOSIT_AMOUNT = 1000000000000000000n;

/**
 * 查询指定地址的链上代码
 * 用于判断地址是 EOA 还是合约
 *
 * @param address - 要查询的地址
 * @param publicClient - 公共客户端
 * @returns 字节码（如果有代码），否则返回 undefined
 */
async function getCodeAtAddress(address: string, publicClient: any) {
  const code = await publicClient.getBytecode({ address: address as `0x${string}` });
  console.log(`地址 ${address} 的链上代码:`, code);
  return code;
}

/**
 * 查询 ERC20 代币余额
 *
 * @param userAddress - 用户地址
 * @param publicClient - 公共客户端
 * @param walletClient - 钱包客户端
 * @returns 代币余额
 */
async function getTokenBalance(userAddress: string, publicClient: any, walletClient: any) {
  const eoaTokenBalance = await publicClient.readContract({
    address: ERC20_ADDRESS,
    abi: ERC20Abi,
    functionName: 'balanceOf',
    args: [userAddress],
  });
  console.log(userAddress, ' ERC20余额:', formatEther(eoaTokenBalance));
  return eoaTokenBalance;
}

/**
 * 主函数：演示 EIP-7702 授权交易流程
 *
 * 流程说明：
 * 1. 检查 Alice 是否已有合约代码（通过 authCode 区分）
 * 2. 如果已有合约代码 → 直接执行批量交易
 * 3. 如果是 EOA → 先签署 EIP-7702 授权，然后执行批量交易
 */
async function main() {
  // ========== 步骤 1: 创建账户 ==========
  // Alice: 被授权的 EOA
  const alice = privateKeyToAccount(ALICE_PRIVATE_KEY as `0x${string}`);
  console.log('Alice 地址:', alice.address);

  // Bob: 第三方执行者
  const bob = privateKeyToAccount(BOB_PRIVATE_KEY as `0x${string}`);
  console.log('Bob 地址:', bob.address);

  // ========== 步骤 2: 创建客户端 ==========
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  });

  const bobWalletClient = createWalletClient({
    account: bob,
    chain: foundry,
    transport: http('http://127.0.0.1:8545'),
  });

  // ========== 步骤 3: 构造交易数据 ==========
  // 批量交易包含两个操作：
  // 1. 授权 TokenBank 合约使用 Alice 的 ERC20 代币
  // 2. 将代币存入 TokenBank 合约

  // 构造 approve 函数调用数据
  // approve(spender, amount)
  const approveCalldata = encodeFunctionData({
    abi: ERC20Abi,
    functionName: 'approve',
    args: [TOKENBANK_ADDRESS, DEPOSIT_AMOUNT],
  });

  // 构造 deposit 函数调用数据
  // deposit(amount)
  const depositCalldata = encodeFunctionData({
    abi: TokenBankAbi,
    functionName: 'deposit',
    args: [DEPOSIT_AMOUNT],
  });

  // ========== 步骤 4: 构造批量调用数组 ==========
  // SimpleDelegate 合约支持批量执行多个调用
  const calls = [
    {
      to: ERC20_ADDRESS,       // 目标合约：ERC20 代币
      data: approveCalldata,   // 调用数据：授权
      value: 0n,               // ETH 价值：0
    },
    {
      to: TOKENBANK_ADDRESS,   // 目标合约：TokenBank
      data: depositCalldata,   // 调用数据：存款
      value: 0n,               // ETH 价值：0
    },
  ];

  // ==========步骤 5: 检查 Alice 账户类型 ==========
  // 查询 Alice 地址的链上代码
  // - 如果有代码：说明已经设置了 EIP-7702 授权
  // - 如果没有代码：说明是普通 EOA
  const code = await getCodeAtAddress(alice.address, publicClient);

  if (code && code.length > 0) {
    // Alice 已有合约代码，直接执行批量交易
    console.log('✅ Alice 已有合约代码（已授权），执行批量交易...');

    // 构造 SimpleDelegate.execute 调用数据
    const executeCalldata = encodeFunctionData({
      abi: SimpleDelegateAbi,
      functionName: 'execute',
      args: [calls],
    });

    // Bob 代表 Alice 发送交易
    const hash = await bobWalletClient.sendTransaction({
      to: alice.address,      // 发送到 Alice 的地址
      data: executeCalldata,  // 执行批量调用
    });
    console.log('直接向 Alice 发送交易, tx hash:', hash);

    // 等待交易确认
    const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: hash });
    console.log('交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
  } else {
    // Alice 是普通 EOA，需要先签署 EIP-7702 授权

    console.log('⚠️ Alice 是普通 EOA，需要签署 EIP-7702 授权...');

    // 创建 Alice 的钱包客户端（用于签名）
    const aliceWalletClient = createWalletClient({
      account: alice,
      chain: foundry,
      transport: http('http://127.0.0.1:8545'),
    });

    // ========== 步骤 6: 生成 EIP-7702 授权 ==========
    // signAuthorization 会生成一个授权消息
    // 该授权指定了 Alice 允许哪个合约在她的地址上执行代码
    const authorization = await aliceWalletClient.signAuthorization({
      account: alice,
      contractAddress: SIMPLE_DELEGATE_ADDRESS,
    });

    console.log('EIP-7702 授权已生成');
    console.log('授权合约:', SIMPLE_DELEGATE_ADDRESS);

    // ========== 步骤 7: 发送 EIP-7702 交易 ==========
    // 使用授权发送交易
    // 授权会在交易执行期间临时赋予 Alice 合约代码
    try {
      const hash = await bobWalletClient.writeContract({
        abi: SimpleDelegateAbi,
        address: alice.address,        // 调用 Alice 的地址
        functionName: 'execute',      // 执行批量调用
        args: [calls],               // 要执行的调用数组
        authorizationList: [authorization],  // EIP-7702 授权
      });
      console.log('✅ EIP-7702 批量交易已发送，tx hash:', hash);

      const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: hash });
      console.log('交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
    } catch (err) {
      console.error('❌ 发送 EIP-7702 交易失败:', err);
    }
  }

  // ========== 步骤 8: 验证结果 ==========
  // 检查 TokenBank 合约中的存款
  console.log('\n========== 验证存款结果 ==========');
  await getTokenBalance(TOKENBANK_ADDRESS, publicClient, bobWalletClient);
  await getTokenBalance(alice.address, publicClient, bobWalletClient);

  // 检查 Alice 的代码状态
  await getCodeAtAddress(alice.address, publicClient);

  /**
   * EIP-7702 安全性说明：
   *
   * 1. 临时授权：授权只在单笔交易期间有效
   * 2. 明确授权：用户需要明确签署授权
   * 3. 可撤销性：用户可以随时撤销授权
   * 4. 范围限制：授权绑定到特定合约地址
   *
   * 应用场景：
   * - 账户抽象（Account Abstraction）
   * - 批量交易（Batch Transactions）
   * - 社交恢复（Social Recovery）
   * - 密钥管理（Key Management）
   * - Gas 赞助（Gas Sponsorship）
   */
}

// 运行主函数
main();
