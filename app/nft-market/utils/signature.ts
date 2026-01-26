import { createPublicClient, http, keccak256, encodePacked } from 'viem';
import { foundry } from 'viem/chains';
import { recoverMessageAddress, toBytes } from 'viem';

// 创建公共客户端实例
export const publicClient = createPublicClient({
  chain: foundry,
  transport: http(),
});

/**
 * 计算截止时间（当前时间 + 1天）
 * @returns 截止时间的时间戳（bigint）
 */
export async function calculateDeadline(): Promise<bigint> {
  try {
    // 获取当前区块的 timestamp
    const block = await publicClient.getBlock();
    const currentTimestamp = block.timestamp; // bigint 类型（秒）

    // 加 1 天（24 * 60 * 60 = 86400 秒）
    const oneDayInSeconds = 86_400n;
    const deadline = currentTimestamp + oneDayInSeconds;

    const date = new Date(Number(deadline) * 1000);
    console.log('Deadline:', date.toLocaleString());
    return deadline;
  } catch (error) {
    console.error('Failed to get block timestamp', error);
    throw new Error('Failed to fetch current block time');
  }
}

/**
 * 生成以太坊签名格式的消息哈希（与合约中使用的 MessageHashUtils.toEthSignedMessageHash 一致）
 */
export function generateEthSignedMessageHash(messageHash: string): string {
  // 在以太坊中，消息哈希需要用特定的格式签名
  // 这等效于 Solidity 中的 MessageHashUtils.toEthSignedMessageHash
  const messageBytes = `0x1901${messageHash.slice(2)}`;
  return keccak256(encodePacked(['bytes'], [messageBytes as `0x${string}`]));
}
