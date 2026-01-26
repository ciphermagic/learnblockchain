import { createPublicClient, formatEther, http, publicActions, parseAbi, webSocket } from 'viem';
import { foundry } from 'viem/chains';
import dotenv from 'dotenv';
import express from 'express';
// @ts-expect-error: better-sqlite3 types are not fully compatible
import Database from 'better-sqlite3';
import cors from 'cors';

dotenv.config();
const ERC20_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

const app = express();
app.use(cors());
app.use(express.json());

const db = new Database('./transfers.db');
db.exec(`
  CREATE TABLE IF NOT EXISTS transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    blockNumber INTEGER,
    txHash TEXT,
    fromAddr TEXT,
    toAddr TEXT,
    value TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

// truncate table
db.exec(`DELETE FROM transfers`);

function insertTransfer(log: any) {
  const { from, to, value } = log.args;
  db.prepare(
    'INSERT OR IGNORE INTO transfers (blockNumber, txHash, fromAddr, toAddr, value) VALUES (?, ?, ?, ?, ?)',
  ).run(log.blockNumber.toString(), log.transactionHash, from.toLowerCase(), to.toLowerCase(), value.toString());
}

// ERC20 Transfer 事件的定义
const scanTransfers = async () => {
  // 创建公共客户端
  const publicClient = createPublicClient({
    chain: foundry,
    transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  console.log('开始扫描 ERC20 事件...');

  // 获取当前区块号
  const currentBlock = await publicClient.getBlockNumber();
  console.log(`当前区块号: ${currentBlock}`);

  // 设置扫描范围（这里扫描最近 1000 个区块）
  // get fromBlock from db
  const fromBlock = 0n;
  const toBlock = currentBlock;

  try {
    // 获取所有 ERC20 事件
    const logs = await publicClient.getLogs({
      fromBlock,
      toBlock,
      // address: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
      // event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)')
      // event: TRANSFER_EVENT
      // multiple events
      events: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
    });

    console.log(`\n在区块 ${fromBlock} 到 ${toBlock} 之间找到 ${logs.length} 个事件`);

    // 处理每个事件
    for (const log of logs) {
      console.log('\n事件详情:');
      console.log(`事件类型: ${log.eventName}`);
      console.log(`合约地址: ${log.address}`);
      console.log(`交易哈希: ${log.transactionHash}`);
      console.log(`区块号: ${log.blockNumber}`);
      console.log(`从: ${log.args.from}`);
      console.log(`到: ${log.args.to}`);
      console.log(`金额: ${formatEther(log.args.value as bigint)}`);

      insertTransfer(log);
      console.log('保存到数据库成功');
    }
  } catch (error) {
    console.error('扫描过程中发生错误:', error);
  }
};

const watchTransfers = async () => {
  // 创建公共客户端
  const publicClient = createPublicClient({
    chain: foundry,
    transport: webSocket(process.env.RPC_URL!),
  }).extend(publicActions);

  console.log('开始监听 ERC20 转账事件...');

  // 监听 Transfer 事件
  publicClient.watchEvent({
    // address: ERC20_ADDRESS,
    event: {
      type: 'event',
      name: 'Transfer',
      inputs: [
        { type: 'address', name: 'from', indexed: true },
        { type: 'address', name: 'to', indexed: true },
        { type: 'uint256', name: 'value' },
      ],
    },
    onLogs: logs => {
      logs.forEach(log => {
        if (log.args.value !== undefined) {
          console.log('\n检测到新的转账事件:');
          console.log(`从: ${log.args.from}`);
          console.log(`到: ${log.args.to}`);
          console.log(`金额: ${formatEther(log.args.value)}`);
          console.log(`交易哈希: ${log.transactionHash}`);
          console.log(`区块号: ${log.blockNumber}`);
          insertTransfer(log);
          console.log('保存到数据库成功');
        }
      });
    },
  });
};

scanTransfers()
  .then(watchTransfers)
  .catch(error => {
    console.error('发生错误:', error);
    process.exit(1);
  });

app.get('/transfers/:address', (req, res) => {
  const address = req.params.address.toLowerCase();
  const rows = db
    .prepare('SELECT * FROM transfers WHERE fromAddr = ? OR toAddr = ? ORDER BY blockNumber DESC')
    .all(address, address);
  res.json(rows);
});

app.listen(3003, () => {
  console.log(`Server running at http://localhost:3003`);
});
