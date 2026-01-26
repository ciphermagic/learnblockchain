import { createPublicClient, http } from 'viem';
import { foundry } from 'viem/chains';
import { keccak256, pad, slice, toHex, hexToBigInt } from 'viem/utils';

// 替换为你的合约地址和 RPC
const contractAddress = '0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E'; // 如 0x...
const client = createPublicClient({
  chain: foundry,
  transport: http(process.env.RPC_URL!),
});

async function readLocks() {
  // 步骤1: 读取数组长度 (slot 0)
  const lengthHex = await client.request({
    method: 'eth_getStorageAt',
    params: [contractAddress, '0x0', 'latest'],
  });
  const length = hexToBigInt(lengthHex);

  console.log(`_locks length: ${length}`);

  // 步骤2: 计算数组数据起始槽 = keccak256(0)
  const arraySlot = '0x0';
  const baseSlot = keccak256(pad(arraySlot));

  for (let i = 0; i < Number(length); i++) {
    // 每个元素占 2 个槽
    const elementBaseSlot = BigInt(baseSlot) + BigInt(i) * 2n;

    // 读取槽1: user (前20 bytes) + startTime (bytes 20-28)
    const slot1 = await client.request({
      method: 'eth_getStorageAt',
      params: [contractAddress, toHex(elementBaseSlot), 'latest'],
    });

    // 读取槽2: amount
    const slot2 = await client.request({
      method: 'eth_getStorageAt',
      params: [contractAddress, toHex(elementBaseSlot + 1n), 'latest'],
    });

    // 解析 user: 左对齐，取前20 bytes
    const user = slice(slot1, 12); // 从 byte 12 开始的 20 bytes (address)

    // 解析 startTime: slot1 的后8 bytes (bytes 24-31)
    const startTimeHex = slice(slot1, 24, 32);
    const startTime = hexToBigInt(startTimeHex);

    // 解析 amount
    const amount = hexToBigInt(slot2);

    console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
  }
}

readLocks().catch(console.error);
