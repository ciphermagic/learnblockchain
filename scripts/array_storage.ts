/**
 * 合约数组存储读取脚本
 *
 * 本脚本演示了如何直接读取 Solidity 合约中的数组类型存储。
 * 通过 eth_getStorageAt RPC 方法，我们可以读取任意存储槽的值，
 * 从而获取合约的内部状态数据。
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 RPC_URL
 * 2. pnpm tsx scripts/array_storage.ts
 *
 * 原理说明：
 * Solidity 中的动态数组存储布局：
 * - 数组长度存储在声明槽位（slot）
 * - 数组数据从 keccak256(slot) 开始连续存储
 * - 每个数组元素占用一个或多个存储槽（取决于元素类型）
 */

import { createPublicClient, http } from 'viem';
import { foundry } from 'viem/chains';
import { keccak256, pad, slice, toHex, hexToBigInt } from 'viem/utils';

// 替换为你要读取的合约地址
// 这个合约应该有一个名为 _locks 的数组类型状态变量
const contractAddress = '0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E';

// 创建公共客户端
const client = createPublicClient({
  chain: foundry,
  transport: http(process.env.RPC_URL!),
});

/**
 * 读取合约中的数组数据
 *
 * Solidity 数组存储布局：
 * - 槽 0: 数组长度（如果是动态数组）
 * - 槽 keccak256(槽位): 数组数据起始位置
 *
 * 每个元素的存储位置计算：
 * - 基础槽 = keccak256(数组槽位)
 * - 元素 i 槽 = 基础槽 + i * 元素大小
 *
 * 对于结构体数组：
 * - 结构体成员紧密排列
 * - 可能跨越多个槽
 */
async function readLocks() {
  // ========== 步骤 1: 读取数组长度 ==========
  // 数组长度存储在声明时的槽位（通常是 0）
  // 返回值是十六进制字符串，需要转换为 BigInt
  const lengthHex = await client.request({
    method: 'eth_getStorageAt',
    params: [contractAddress, '0x0', 'latest'],
  });
  const length = hexToBigInt(lengthHex);

  console.log(`_locks 数组长度: ${length}`);

  // 如果数组为空，直接返回
  if (length === 0n) {
    console.log('数组为空，无需读取');
    return;
  }

  // ========== 步骤 2: 计算数组数据起始槽 ==========
  // 数组数据的存储位置 = keccak256(数组槽位)
  // 这里假设数组声明在槽 0
  const arraySlot = '0x0';
  const baseSlot = keccak256(pad(arraySlot));

  console.log(`数组数据起始槽: ${baseSlot}`);

  // ========== 步骤 3: 遍历读取每个元素 ==========
  // 这里假设数组元素是结构体，包含：
  // - user: address (20 bytes)
  // - startTime: uint256 (32 bytes，但只用 8 bytes)
  // - amount: uint256 (32 bytes)
  //
  // 由于结构体紧密排列：
  // - slot[i]: user (bytes 0-19) + startTime (bytes 20-31)
  // - slot[i+1]: amount
  for (let i = 0; i < Number(length); i++) {
    // 每个元素占 2 个槽（结构体紧密排列）
    const elementBaseSlot = BigInt(baseSlot) + BigInt(i) * 2n;

    // ========== 步骤 4: 读取第一个槽 ==========
    // 包含 user 地址和 startTime
    const slot1 = await client.request({
      method: 'eth_getStorageAt',
      params: [contractAddress, toHex(elementBaseSlot), 'latest'],
    });

    // ========== 步骤 5: 读取第二个槽 ==========
    // 包含 amount
    const slot2 = await client.request({
      method: 'eth_getStorageAt',
      params: [contractAddress, toHex(elementBaseSlot + 1n), 'latest'],
    });

    // ========== 步骤 6: 解析存储数据 ==========
    // 解析 user: 从 slot1 的前 20 bytes（地址长度）
    // slice(slot1, 12) 跳过前 12 bytes（24 个十六进制字符），保留后 20 bytes
    const user = slice(slot1, 12); // 从 byte 12 开始的 20 bytes (address)

    // 解析 startTime: slot1 的后 8 bytes (bytes 24-31)
    const startTimeHex = slice(slot1, 24, 32);
    const startTime = hexToBigInt(startTimeHex);

    // 解析 amount: 直接解析 slot2
    const amount = hexToBigInt(slot2);

    // 输出解析结果
    console.log(`locks[${i}]:`);
    console.log(`  user: ${user}`);
    console.log(`  startTime: ${startTime} (${new Date(Number(startTime) * 1000).toISOString()})`);
    console.log(`  amount: ${amount}`);
  }
}

/**
 * Solidity 存储布局速查表：
 *
 * 类型              | 槽位计算方式
 * -----------------|--------------------------------
 * uint256          | slot[i]
 * address          | slot[i] (后 20 bytes)
 * bytes32          | slot[i]
 * uint8            | slot[i] (最低位字节)
 * mapping          | keccak256(key . slot)
 * array (dynamic)  | length: slot
 *                   | data: keccak256(slot)
 * array (fixed)    | slot[i]
 * struct           | slot[i], slot[i+1], ...
 *
 * 注意：
 * - 基础类型紧密排列
 * - 每个类型占用 32 bytes 的槽位
 * - 结构体成员紧密排列，可能跨越多个槽
 */

// 运行主函数
readLocks().catch(console.error);
