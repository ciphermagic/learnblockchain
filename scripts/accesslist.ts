/**
 * Access List 演示脚本
 * 
 * 本脚本演示了如何使用以太坊的访问列表（Access List）功能来优化交易 gas 成本。
 * Access List 是 EIP-2930 引入的特性，允许交易预先声明需要访问的存储槽和账户，
 * 从而在 EIP-3709 中降低 gas 消耗。
 * 
 * 访问列表的主要优势：
 * 1. 减少 cold storage 访问的 gas 成本（从 2100 降至 100）
 * 2. 提前声明需要访问的存储位置
 * 3. 对于涉及多个账户的交易特别有效
 */

import { createPublicClient, createWalletClient, http, parseAbi, keccak256, encodePacked, pad, encodeFunctionData } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";

/**
 * 使用私钥创建账户
 * 这是一个测试账户的私钥（Hardhat/Anvil 默认的第一个账户）
 * 在生产环境中请勿使用硬编码的私钥
 */
const account = privateKeyToAccount(
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
);

/**
 * 创建公共客户端
 * 用于调用只读方法（如 estimateGas、eth_createAccessList 等）
 */
const publicClient = createPublicClient({
  chain: foundry,
  transport: http("http://127.0.0.1:8545"),
});

/**
 * 创建钱包客户端
 * 用于发送交易
 */
const walletClient = createWalletClient({
  account,
  chain: foundry,
  transport: http("http://127.0.0.1:8545"),
});

// USDC 代币合约地址（示例地址）
const usdc = {
    address: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512" as const,
};

// ERC20 transfer 函数的 ABI 解析
const erc20Abi = parseAbi([
  "function transfer(address to, uint256 value) returns (bool)",
]);

/**
 * 计算 mapping(address => uint256) 类型的存储槽位置
 * 
 * 在以太坊中，mapping 类型的存储布局如下：
 * - key 经过 keccak256 编码后作为存储槽
 * - slotIndex 是 mapping 变量声明时的槽位索引
 * 
 * @param addr - mapping 的键（地址）
 * @param slotIndex - mapping 变量的存储槽索引
 * @returns 计算后的存储槽哈希值
 */
function computeMappingSlot(addr: `0x${string}`, slotIndex: bigint): `0x${string}` {
    return keccak256(
        encodePacked(
        ["bytes32", "bytes32"],
        [pad(addr as `0x${string}`, { size: 32 }), pad(`0x${slotIndex.toString(16)}` as `0x${string}`, { size: 32 })]
        )
    );
}

/**
 * 主函数：演示 Access List 的使用
 * 
 * 流程：
 * 1. 普通 gas 估算（不使用 Access List）
 * 2. 使用 eth_createAccessList 获取推荐的访问列表
 * 3. 手动计算 storage slot（验证 eth_createAccessList 的结果）
 * 4. 使用 Access List 再次估算 gas
 * 5. 实际执行交易并比较 gas 使用量
 */
async function main() {
    // 目标地址（burn 地址）
    const to = "0x000000000000000000000000000000000000dEaD";
    // 转账金额（1 USDC，假设 USDC 精度为 6）
    const amount = 1_000_000n;

    // 编码 transfer 函数调用数据
    const data = encodeFunctionData({
        abi: erc20Abi,
        functionName: "transfer",
        args: [to, amount],
    });

    // ========== 步骤 1: 普通 gas 估算（不使用 Access List） ==========
    // 这种估算方式假设所有访问都是 cold storage，会得到较高的 gas 估算
    const gasNormal = await publicClient.estimateGas({
        account,
        to: usdc.address,
        data,
    });
    console.log("Normal transfer gas:", gasNormal);

    // ========== 步骤 2: 使用 eth_createAccessList ==========
    // eth_createAccessList 是以太坊 JSON-RPC 方法，会分析交易并返回推荐的访问列表
    // 该方法会识别哪些存储槽会被访问（通过静态分析合约代码）
    const res = await publicClient.request({
        method: "eth_createAccessList",
        params: [
        {
            from: account.address,
            to: usdc.address,
            data,
            value: "0x0",
        },
        "latest",
        ],
    });
    console.log("eth_createAccessList gasUsed:", res.gasUsed);
    console.log("Recommended accessList:", res.accessList);

    // ========== 步骤 3: 手动计算 storage slot ==========
    // 对于 ERC20 的 balanceOf mapping：
    // - mapping 变量通常存储在 slot 0
    // - 需要计算 balanceOf[from] 和 balanceOf[to] 的存储槽
    // 这是手动验证 eth_createAccessList 结果的方法
    const slotFrom = computeMappingSlot(account.address, 0n);
    const slotTo = computeMappingSlot(to, 0n);

    console.log("Computed slot(from):", slotFrom);
    console.log("Computed slot(to):  ", slotTo);

    // ========== 步骤 4: 使用 Access List 再次估算 gas ==========
    // 使用 eth_createAccessList 返回的访问列表进行 gas 估算
    // 由于已预先声明访问的存储槽，可以避免 cold storage 访问的高成本
    const gasWithAccessList = await publicClient.estimateGas({
        account,
        to: usdc.address,
        data,
        accessList: res.accessList,
    });
    console.log("Transfer with accessList gas:", gasWithAccessList);

    // ========== 步骤 5: 实际执行交易（带 Access List） ==========
    // 发送交易时附带 accessList，让以太坊节点知道哪些存储槽会被访问
    // 这在 EIP-3709 兼容的网络上可以节省 gas
    const hash = await walletClient.sendTransaction({
        to: usdc.address,
        data,
        accessList: res.accessList,
        gas: gasWithAccessList,
    });
    console.log("Tx sent:", hash);

    // 等待交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log("Tx receipt gasUsed:", receipt.gasUsed);
}

// 运行主函数并捕获错误
main().catch(console.error);
