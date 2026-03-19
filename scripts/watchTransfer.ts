/**
 * ERC20 转账事件监听与存储脚本
 *
 * 本脚本演示了如何：
 * 1. 扫描历史区块中的 ERC20 Transfer 事件
 * 2. 实时监听新的 ERC20 转账事件
 * 3. 将事件数据存储到 SQLite 数据库
 * 4. 提供 REST API 查询转账记录
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 RPC_URL
 * 2. pnpm tsx scripts/watchTransfer.ts
 * 3. 访问 http://localhost:3003/transfers/:address 查询转账记录
 *
 * 技术要点：
 * - 使用 WebSocket 实现实时监听
 * - 使用 better-sqlite3 存储数据
 * - 使用 Express 提供 HTTP API
 */

import { createPublicClient, formatEther, http, publicActions, parseAbi, webSocket } from 'viem';
import { foundry } from 'viem/chains';
import dotenv from 'dotenv';
import express from 'express';
// @ts-expect-error: better-sqlite3 types are not fully compatible
import Database from 'better-sqlite3';
import cors from 'cors';

dotenv.config();

// ERC20 代币合约地址（示例）
const ERC20_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

// ========== Express 服务器设置 ==========
const app = express();
app.use(cors());  // 允许跨域请求
app.use(express.json());  // 解析 JSON 请求体

// ========== SQLite 数据库初始化 ==========
// 创建数据库文件
const db = new Database('./transfers.db');

// 创建转账记录表
db.exec(`
  CREATE TABLE IF NOT EXISTS transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,    -- 自增主键
    blockNumber INTEGER,                      -- 区块号
    txHash TEXT,                             -- 交易哈希
    fromAddr TEXT,                           -- 转出地址
    toAddr TEXT,                             -- 转入地址
    value TEXT,                              -- 转账金额（wei 格式）
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP  -- 记录时间
  )
`);

// 清空表（可选，用于测试）
db.exec(`DELETE FROM transfers`);

/**
 * 插入转账记录到数据库
 * @param log - 从事件中获取的日志数据
 */
function insertTransfer(log: any) {
  const { from, to, value } = log.args;

  // 使用预处理语句防止 SQL 注入
  // 将地址转为小写存储，便于查询匹配
  db.prepare(
    'INSERT OR IGNORE INTO transfers (blockNumber, txHash, fromAddr, toAddr, value) VALUES (?, ?, ?, ?, ?)'
  ).run(log.blockNumber.toString(), log.transactionHash, from.toLowerCase(), to.toLowerCase(), value.toString());
}

/**
 * 扫描历史区块中的 ERC20 Transfer 事件
 *
 * 使用 publicClient.getLogs 获取历史日志
 * 这是只读操作，不会修改区块链状态
 */
const scanTransfers = async () => {
  // 创建公共客户端（使用 HTTP 传输）
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  console.log('开始扫描 ERC20 事件...');

  // 获取当前区块号
  const currentBlock = await publicClient.getBlockNumber();
  console.log(`当前区块号: ${currentBlock}`);

  // 设置扫描范围
  // 从创世区块开始扫描到当前区块
  // 生产环境中建议分段扫描，避免请求超时
  const fromBlock = 0n;
  const toBlock = currentBlock;

  try {
    // 获取所有符合条件的日志
    const logs = await publicClient.getLogs({
      fromBlock,
      toBlock,
      // 解析 ERC20 Transfer 事件 ABI
      // event Transfer(address indexed from, address indexed to, uint256 value)
      events: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
    });

    console.log(`\n在区块 ${fromBlock} 到 ${toBlock} 之间找到 ${logs.length} 个 Transfer 事件`);

    // 遍历处理每个事件
    for (const log of logs) {
      console.log('\n========== 事件详情 ==========');
      console.log(`事件类型: ${log.eventName}`);
      console.log(`合约地址: ${log.address}`);
      console.log(`交易哈希: ${log.transactionHash}`);
      console.log(`区块号: ${log.blockNumber}`);
      console.log(`转出地址: ${log.args.from}`);
      console.log(`转入地址: ${log.args.to}`);
      console.log(`转账金额: ${formatEther(log.args.value as bigint)}`);

      // 保存到数据库
      insertTransfer(log);
      console.log('✅ 保存到数据库成功');
    }
  } catch (error) {
    console.error('扫描过程中发生错误:', error);
  }
};

/**
 * 实时监听新的 ERC20 转账事件
 *
 * 使用 WebSocket 传输实现实时推送
 * publicClient.watchEvent 会持续监听新产生的日志
 */
const watchTransfers = async () => {
  // 创建公共客户端（使用 WebSocket 传输）
  const publicClient = createPublicClient({
    chain: foundry,
    transport: webSocket(process.env.RPC_URL!),
  }).extend(publicActions);

  console.log('\n开始监听 ERC20 转账事件（实时）...');

  // 监听 Transfer 事件
  // 当新区块产生包含该事件的交易时，会触发回调
  const unwatch = publicClient.watchEvent({
    // 可以指定特定合约地址，不指定则监听所有
    // address: ERC20_ADDRESS,

    // 定义要监听的事件
    event: {
      type: 'event',
      name: 'Transfer',
      inputs: [
        { type: 'address', name: 'from', indexed: true },
        { type: 'address', name: 'to', indexed: true },
        { type: 'uint256', name: 'value' },
      ],
    },

    // 事件回调函数
    onLogs: logs => {
      logs.forEach(log => {
        // 过滤掉无效的日志
        if (log.args.value !== undefined) {
          console.log('\n========== 检测到新的转账事件 ==========');
          console.log(`转出地址: ${log.args.from}`);
          console.log(`转入地址: ${log.args.to}`);
          console.log(`转账金额: ${formatEther(log.args.value)} ETH`);
          console.log(`交易哈希: ${log.transactionHash}`);
          console.log(`区块号: ${log.blockNumber}`);

          // 保存到数据库
          insertTransfer(log);
          console.log('✅ 保存到数据库成功');
        }
      });
    },
  });

  console.log('监听已启动，按 Ctrl+C 停止\n');

  // 返回取消监听的函数
  return unwatch;
};

/**
 * REST API 端点
 * 查询指定地址的转账记录
 */
app.get('/transfers/:address', (req, res) => {
  const address = req.params.address.toLowerCase();

  // 查询该地址的所有转入和转出记录
  const rows = db
    .prepare('SELECT * FROM transfers WHERE fromAddr = ? OR toAddr = ? ORDER BY blockNumber DESC')
    .all(address, address);

  res.json(rows);
});

// ========== 启动服务器 ==========
const PORT = 3003;
app.listen(PORT, () => {
  console.log(`\n🚀 REST API 服务器运行在 http://localhost:${PORT}`);
  console.log(`使用方法: GET http://localhost:${PORT}/transfers/:address`);
  console.log(`示例: GET http://localhost:${PORT}/transfers/0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`);
});

/**
 * 执行流程：
 * 1. 先扫描历史事件（scanTransfers）
 * 2. 然后开始实时监听（watchTransfers）
 * 3. 提供 HTTP API 供查询
 */
scanTransfers()
  .then(watchTransfers)
  .catch(error => {
    console.error('发生错误:', error);
    process.exit(1);
  });
