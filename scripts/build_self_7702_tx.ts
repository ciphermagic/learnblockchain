/**
 * build_self_7702_tx.ts - EIP-7702 批量交易授权执行示例
 *
 * 本脚本演示 EIP-7702 的核心功能：让普通 EOA（外部拥有账户）临时获得合约执行能力
 *
 * 🎯 EIP-7702 核心概念：
 *
 * 1. 授权机制（Authorization）：
 *    - 传统的 EOA（如 0x1234...）没有代码，只能发起简单转账
 *    - EIP-7702 允许 EOA 临时获得一个合约代码（称为 "授权"）
 *    - 授权后，该 EOA 可以像合约一样执行复杂操作（批量调用、代理执行等）
 *    - 授权可以通过发送另一个交易来撤销（设置 code = 0）
 *
 * 2. 批量调用（Batch Calls）：
 *    - 可以在单笔交易中执行多个操作
 *    - 典型场景：授权 + 存款 一步完成
 *    - 节省交易费（比分开执行省一次基础费用）
 *
 * 3. 交易流程：
 *    - 情况 A：EOA 已有代码（已授权）→ 直接发送调用
 *    - 情况 B：EOA 无代码（未授权）→ 先授权，再执行调用
 *
 * 4. nonce 变化：
 *    - 授权交易需要 nonce + 1
 *    - 执行交易也需要 nonce + 1
 *    - 两笔交易的 nonce 是连续的
 *
 * 📝 使用方法：
 * 1. 确保本地启动了 anvil: anvil
 * 2. 部署 SimpleDelegate, ERC20, TokenBank 合约
 * 3. 修改脚本中的合约地址配置
 * 4. 运行: pnpm tsx scripts/build_self_7702_tx.ts
 */

import {
  createPublicClient,
  createWalletClient,
  http,
  encodeFunctionData,
  formatEther,
  zeroAddress,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { foundry } from 'viem/chains';
import type { TransactionReceipt } from 'viem';

// 导入合约 ABI（用于编码函数调用）
import SimpleDelegateAbi from '@/abis/SimpleDelegate.json' with { type: 'json' };
import ERC20Abi from '@/abis/MyERC20.json' with { type: 'json' };
import TokenBankAbi from '@/abis/TokenBank.json' with { type: 'json' };

// ==================== 配置区域 ====================
/**
 * 测试用私钥（anvil 默认账户 #0）
 * 注意：这是硬编码的测试私钥，不要在生产环境使用！
 */
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

/**
 * 合约部署地址（需要根据实际部署情况修改）
 * - SimpleDelegate: EIP-7702 代理执行合约
 * - ERC20: 测试用 ERC20 代币
 * - TokenBank: 存款合约
 */
const SIMPLE_DELEGATE_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';
const ERC20_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
const TOKENBANK_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0';

// 存款金额 = 1 Token（以最小单位表示）
const DEPOSIT_AMOUNT = 1000000000000000000n; // 1 token

// ==================== 辅助函数 ====================

/**
 * 查询指定地址的链上代码
 *
 * 在 EIP-7702 中，我们通过检查 EOA 是否有代码来判断是否已授权：
 * - code === undefined 或 code === '0x' 或 code.length === 0：未授权
 * - code 有实际内容：已授权（临时获得了合约代码）
 *
 * @param address - 要查询的地址
 * @param publicClient - 公共客户端
 * @returns 链上代码（如果有）
 */
async function getCodeAtAddress(address: string, publicClient: any) {
  // getBytecode 返回指定地址的合约字节码
  // 如果地址没有代码，返回 '0x'（空字节码）
  const code = await publicClient.getBytecode({ address: address as `0x${string}` });
  console.log(`地址 ${address} 的链上代码:`, code);
  return code;
}

/**
 * 查询指定地址的 ERC20 代币余额
 *
 * @param userAddress - 要查询的地址
 * @param publicClient - 公共客户端
 * @param walletClient - 钱包客户端（此处未使用，仅保留接口一致性）
 * @returns 代币余额
 */
async function getTokenBalance(userAddress: string, publicClient: any, walletClient: any) {
  // 使用 readContract 进行只读合约调用
  const eoaTokenBalance = await publicClient.readContract({
    address: ERC20_ADDRESS,
    abi: ERC20Abi,
    functionName: 'balanceOf',
    args: [userAddress],
  });
  console.log(userAddress, ' ERC20余额:', formatEther(eoaTokenBalance));
  return eoaTokenBalance;
}

// ==================== 主函数 ====================

/**
 * EIP-7702 批量交易执行主流程
 *
 * 完整流程说明：
 * 1. 创建账户和客户端
 * 2. 构造批量调用的 calldata（approve + deposit）
 * 3. 检查 EOA 是否已有授权代码
 * 4a. 如果已有代码：直接发送交易
 * 4b. 如果没有代码：先授权，再执行
 * 5. 执行完成后撤销授权（恢复为普通 EOA）
 */
async function main() {
  // 步骤 1: 从私钥创建 EOA 账户
  const eoa = privateKeyToAccount(PRIVATE_KEY as `0x${string}`);

  // 创建 PublicClient（用于读取链上数据）
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  });

  // 创建 WalletClient（用于签名和发送交易）
  const walletClient = createWalletClient({
    account: eoa,
    chain: foundry,
    transport: http('http://127.0.0.1:8545'),
  });

  // 步骤 2: 构造批量调用的 calldata
  // 我们要执行两个操作：
  // 1. approve: 授权 TokenBank 可以转移我们的代币
  // 2. deposit: 向 TokenBank 存款

  // 2.1 构造 approve 的 calldata
  // encodeFunctionData 将函数调用编码为合约可执行的字节数据
  // 相当于 Solidity 中: tokenBank.approve(address(this), amount)
  const approveCalldata = encodeFunctionData({
    abi: ERC20Abi,
    functionName: 'approve',
    args: [TOKENBANK_ADDRESS, DEPOSIT_AMOUNT],
  });

  // 2.2 构造 deposit 的 calldata
  // 相当于 Solidity 中: tokenBank.deposit(amount)
  const depositCalldata = encodeFunctionData({
    abi: TokenBankAbi,
    functionName: 'deposit',
    args: [DEPOSIT_AMOUNT],
  });

  // 步骤 3: 构造批量调用数组
  // SimpleDelegate 合约的 execute 函数接受一个 calls 数组
  // 每个 call 包含：
  // - to: 目标合约地址
  // - data: 要调用的函数编码
  // - value: 要发送的 ETH 数量（0 表示不发送 ETH）
  const calls = [
    {
      to: ERC20_ADDRESS, // 目标：ERC20 合约
      data: approveCalldata, // 数据：approve 函数调用
      value: 0n, // 不发送 ETH
    },
    {
      to: TOKENBANK_ADDRESS, // 目标：TokenBank 合约
      data: depositCalldata, // 数据：deposit 函数调用
      value: 0n, // 不发送 ETH
    },
  ];

  // 步骤 4: 构造最终的 execute calldata
  // 将批量调用数组包装为 SimpleDelegate.execute 的参数
  const executeCalldata = encodeFunctionData({
    abi: SimpleDelegateAbi,
    functionName: 'execute',
    args: [calls],
  });

  // 查看执行前的代币余额
  await getTokenBalance(eoa.address, publicClient, walletClient);

  // 步骤 5: 检查 EOA 的授权状态
  // 这是 EIP-7702 的核心判断逻辑
  console.log('🔍 检查 EOA 授权状态...');
  const code = await getCodeAtAddress(eoa.address, publicClient);
  console.log('📋 EOA 当前状态:', code && code.length > 0 ? '已授权（有合约代码）' : '未授权（普通 EOA）');

  // ==================== 分支处理 ====================
  /**
   * 情况 A：EOA 已有代码（已授权）
   * - 这意味着之前已经执行过 EIP-7702 授权
   * - 此时可以直接向 EOA 地址发送交易，EOA 会作为合约执行
   * - 不需要再次授权
   *
   * 情况 B：EOA 没有代码（未授权）
   * - 这是普通 EOA，需要先获得授权
   * - 通过 signAuthorization 创建一个授权记录
   * - 授权交易会设置 EOA 的代码为 SimpleDelegate 合约代码
   */

  if (code && code.length > 0) {
    // ========== 情况 A: 已有授权 ==========
    console.log('✅ EOA 已有授权代码，直接执行批量调用');

    // 直接向 EOA 地址发送交易
    // 由于 EOA 已有 SimpleDelegate 代码，这笔交易会作为合约调用执行
    // EOA 会解析 calldata 并执行批量调用
    const hash = await walletClient.sendTransaction({
      to: eoa.address, // 发送给自己
      data: executeCalldata, // 执行批量调用
    });
    console.log('📤 批量交易已发送, tx hash:', hash);

    const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: hash });
    console.log('🎉 交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
  } else {
    // ========== 情况 B: 未授权，需要先授权 ==========
    console.log('🔐 EOA 未授权，需要先进行 EIP-7702 授权');

    /**
     * signAuthorization 创建授权签名
     *
     * 参数说明：
     * - contractAddress: 要授权的合约地址（SimpleDelegate）
     *   授权后，EOA 会临时获得这个合约的代码
     *
     * - executor: 'self'
     *   表示 EOA 自己执行授权的合约代码
     *   另一个选项是授权给另一个地址（由那个地址执行）
     *
     * 签名内容会被包含在交易中，设置 EOA 的代码
     */
    const authorization = await walletClient.signAuthorization({
      contractAddress: SIMPLE_DELEGATE_ADDRESS,
      executor: 'self',
    });

    console.log('✍️ 已创建授权签名');

    // 发送 EIP-7702 交易
    // 这个交易会：
    // 1. 首先执行授权（设置 EOA 的代码为 SimpleDelegate）
    // 2. 然后执行 execute 函数（批量调用）
    // 两步都在同一笔交易中完成！
    try {
      const hash = await walletClient.writeContract({
        abi: SimpleDelegateAbi,
        address: eoa.address, // 调用 EOA 地址
        functionName: 'execute',
        args: [calls],
        authorizationList: [authorization], // 包含授权信息
      });

      console.log('📤 EIP-7702 批量交易已发送, tx hash:', hash);

      const receipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: hash });
      console.log('🎉 交易状态:', receipt.status === 'success' ? '✅ 成功' : '❌ 失败');
    } catch (err) {
      console.error('❌ 发送 EIP-7702 交易失败:', err);
    }
  }

  // 步骤 6: 检查交易执行结果
  // 查看 TokenBank 和用户的代币余额变化
  console.log('\n📊 交易执行后余额查询:');
  await getTokenBalance(TOKENBANK_ADDRESS, publicClient, walletClient);
  await getTokenBalance(eoa.address, publicClient, walletClient);

  // 步骤 7: 撤销授权（恢复为普通 EOA）
  /**
   * 撤销授权的原理：
   * - 将 contractAddress 设置为 zeroAddress (0x000...0)
   * - 这会将 EOA 的代码设置回空（'0x'）
   * - EOA 恢复为普通账户，无法执行合约调用
   */
  console.log('\n🔙 开始撤销授权...');

  const cancelAuthorization = await walletClient.signAuthorization({
    contractAddress: zeroAddress, // 0x000...000 表示清除代码
    executor: 'self',
  });

  const cancelHash = await walletClient.sendTransaction({
    authorizationList: [cancelAuthorization],
    to: zeroAddress, // 发送到 zeroAddress
  });

  const cancelReceipt: TransactionReceipt = await publicClient.waitForTransactionReceipt({ hash: cancelHash });
  console.log('🎉 撤销授权交易状态:', cancelReceipt.status === 'success' ? '✅ 成功' : '❌ 失败');

  // 验证授权已撤销
  await getCodeAtAddress(eoa.address, publicClient);
}

// 执行主函数
main();
