/**
 * WETH (Wrapped Ether) 交互脚本
 *
 * 本脚本演示了如何与 WETH 合约进行交互。
 * WETH 是 ETH 的 ERC20 封装代币，1 WETH = 1 ETH
 *
 * 使用方法:
 * 1. 先在 .env 文件中配置 PRIVATE_KEY 和 RPC_URL
 * 2. pnpm tsx scripts/weth.ts
 *
 * WETH 合约地址（Base Sepolia 测试网）: 0x4200000000000000000000000000000000000006
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
} from 'viem';
import { baseSepolia, foundry } from 'viem/chains';
import dotenv from 'dotenv';
import WETH_ABI from '@/abis/weth.json' with { type: 'json' };
import { privateKeyToAccount } from 'viem/accounts';

dotenv.config();

// WETH 合约地址（Base Sepolia 测试网）
// Base 网络上的 WETH 合约地址是标准的
const WETH_ADDRESS = '0x4200000000000000000000000000000000000006';

/**
 * 主函数：演示 WETH 合约的各种操作
 */
const main = async () => {
  // ========== 步骤 1: 创建公共客户端 ==========
  // 公共客户端用于执行只读操作，如查询余额、读取合约状态等
  // 使用 Base Sepolia 测试网
  const publicClient = createPublicClient({
    chain: baseSepolia, // mainnet, sepolia, base, baseSepolia, ...
    transport: http(), // 使用默认的 HTTP 传输
  });

  // 获取当前区块号
  const blockNumber = await publicClient.getBlockNumber();
  console.log(`当前区块号: ${blockNumber}`);

  // ========== 步骤 2: 查询账户 ETH 余额 ==========
  // 使用 formatEther 将 wei 转换为 ETH（精度 18 位）
  const tbalance = formatEther(
    await publicClient.getBalance({
      address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    }),
  );

  console.log(`地址 0xf39 的 ETH 余额: ${tbalance}`);

  // ========== 步骤 3: 创建钱包客户端 ==========
  // 钱包客户端用于执行需要私钥签名的操作，如发送交易
  const account = privateKeyToAccount(process.env.PRIVATE_KEY! as `0x${string}`);

  const walletClient = createWalletClient({
    account,
    chain: foundry, // 使用本地 Foundry 网络进行测试
    transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  // 获取钱包地址
  const address = await walletClient.getAddresses();

  // ========== 步骤 4: 创建 WETH 合约实例 ==========
  // 使用 getContract 创建合约实例，方便调用合约的读写方法
  const wethContract = getContract({
    address: WETH_ADDRESS,
    abi: WETH_ABI,
    client: {
      public: publicClient,   // 只读客户端
      wallet: walletClient,   // 写操作客户端
    },
  });

  // ========== 步骤 5: 读取 WETH 余额（方法 1） ==========
  // 使用合约实例的 read 方法
  const balance1 = formatEther(BigInt((await wethContract.read.balanceOf([address.toString()])) as string));
  console.log(`方法 1 - 地址 ${address.toString()} 的 WETH 余额: ${balance1}`);

  // ========== 步骤 6: 读取 WETH 余额（方法 2） ==========
  // 使用 publicClient.readContract 直接读取
  const balance = formatEther(
    BigInt(
      (await publicClient.readContract({
        address: WETH_ADDRESS,
        abi: WETH_ABI,
        functionName: 'balanceOf',
        args: [address.toString()],
      })) as string,
    ),
  );
  console.log(`方法 2 - 地址 ${address.toString()} 的 WETH 余额: ${balance}`);

  // ========== 步骤 7: 存款到 WETH 合约（ETH 包装） ==========
  // 将 ETH 存入 WETH 合约，换取等量的 WETH
  // 这是一个非常有用的操作，因为很多 DeFi 协议需要 ERC20 格式的 ETH
  /*
  const depositHash = await wethContract.write.deposit([], {
      value: parseEther("0.000001"), // 存入 0.000001 ETH
  });
  console.log(`存款交易哈希: ${depositHash}`);
  */

  // 或者使用 walletClient.writeContract 方式：
  /*
  const depositHash = await walletClient.writeContract({
      address: WETH_ADDRESS,
      abi: WETH_ABI,
      functionName: 'deposit',
      args: [],
      value: parseEther("0.000001")
  });
  console.log(`存款交易哈希: ${depositHash}`);
  */

  // ========== 步骤 8: 从 WETH 合约提款（ETH 解封装） ==========
  // 将 WETH 换回 ETH
  // 调用 withdraw 函数会燃烧（销毁）指定数量的 WETH，并释放等量的 ETH 给调用者
  /*
  const withdrawAmount = parseEther("0.000001");
  const withdrawHash = await wethContract.write.withdraw([withdrawAmount]);
  console.log(`提款交易哈希: ${withdrawHash}`);
  */

  // ========== 步骤 9: WETH 转账 ==========
  // 和普通 ERC20 代币一样的转账操作
  /*
  const transferHash = await wethContract.write.transfer([
      '0xRecipientAddress',  // 接收者地址
      parseEther("0.001")    // 转账数量
  ]);
  console.log(`转账交易哈希: ${transferHash}`);
  */
};

/**
 * WETH 合约的关键函数说明：
 *
 * 1. deposit() - 存款（包装 ETH）
 *    - 用途：将 ETH 存入合约，换取等量的 WETH
 *    - 调用方式：sendTransaction({ value: parseEther("1") })
 *    - 无需额外参数，发送的 ETH 数量决定获得的 WETH 数量
 *
 * 2. withdraw(uint256 wad) - 提款（解封装 WETH）
 *    - 用途：燃烧 WETH，换取等量的 ETH
 *    - 参数：wad - 要提取的 WETH 数量（以 wei 为单位）
 *
 * 3. transfer(address to, uint256 wad) - 转账
 *    - 用途：像普通 ERC20 一样转移 WETH
 *    - 参数：to - 接收地址，wad - 转移数量
 *
 * 4. balanceOf(address guy) - 查询余额
 *    - 用途：查询指定地址的 WETH 余额
 *    - 返回值：uint256 类型的余额
 */

// 运行主函数
main();
