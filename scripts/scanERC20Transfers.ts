/**
 * ERC20 转账扫描工具
 *
 * 功能:
 * - 扫描历史区块中的 ERC20 Transfer 事件
 * - 实时监听新发生的转账事件
 * - 将转账记录存储到 SQLite 数据库
 * - 提供 REST API 查询转账记录
 *
 * 技术原理:
 * - 使用 Viem 库的公共客户端连接以太坊节点
 * - 通过 getLogs API 获取历史事件
 * - 通过 watchEvent 订阅新事件
 * - 解析事件日志中的 Transfer 事件
 *
 * ERC20 Transfer 事件:
 * - Event Signature: Transfer(address indexed from, address indexed to, uint256 value)
 * - Keccak256 哈希: 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
 * - indexed 参数存储在 topics 中
 * - 非 indexed 参数存储在 data 中
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 RPC_URL
 * 2. 运行: pnpm tsx scripts/scanERC20Transfers.ts
 * 3. 访问 API: http://localhost:3003/transfers/:address
 *
 * 依赖:
 * - viem: 以太坊交互库
 * - better-sqlite3: SQLite 数据库
 * - express: HTTP 服务器
 * - dotenv: 环境变量管理
 */
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

// ============================================
// 数据库初始化
// ============================================

// 创建 SQLite 数据库连接
// transfers.db 会在当前目录创建
const db = new Database('./transfers.db');

// 创建转账记录表
// 表结构:
// - id: 主键，自增
// - blockNumber: 区块号
// - txHash: 交易哈希
// - fromAddr: 转出地址
// - toAddr: 转入地址
// - value: 转账金额（字符串形式，保留精度）
// - timestamp: 记录创建时间
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

// 清空现有数据（可选）
// 实际使用时可能需要注释掉这行
db.exec(`DELETE FROM transfers`);

/**
 * 将转账记录插入数据库
 * @param {object} log - 事件日志对象
 *
 * 数据处理:
 * - 地址转换为小写存储（便于查询匹配）
 * - 金额保持字符串形式（JavaScript 大数精度问题）
 * - 使用 INSERT OR IGNORE 防止重复插入
 */
function insertTransfer(log: any) {
  const { from, to, value } = log.args;
  db.prepare(
    'INSERT OR IGNORE INTO transfers (blockNumber, txHash, fromAddr, toAddr, value) VALUES (?, ?, ?, ?, ?)',
  ).run(log.blockNumber.toString(), log.transactionHash, from.toLowerCase(), to.toLowerCase(), value.toString());
}

// ============================================
// 历史扫描功能
// ============================================

/**
 * 扫描历史区块中的 ERC20 Transfer 事件
 *
 * 工作流程:
 * 1. 创建公共客户端连接以太坊节点
 * 2. 获取当前区块号
 * 3. 设置扫描范围（fromBlock 到 toBlock）
 * 4. 调用 getLogs 获取事件日志
 * 5. 解析每个日志并存储到数据库
 *
 * getLogs 限制:
 * - 大多数节点对查询范围有限制
 * - 主网通常限制为 10000 个区块
 * - 需要分批查询大范围数据
 */
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

// ============================================
// 实时监听功能
// ============================================

/**
 * 实时监听 ERC20 Transfer 事件
 *
 * 工作原理:
 * 1. 使用 WebSocket 连接到以太坊节点
 * 2. 订阅新产生的区块和日志
 * 3. 当新区块中有 Transfer 事件时触发回调
 * 4. 实时处理并存储新的转账记录
 *
 * WebSocket vs HTTP:
 * - HTTP: 主动查询，适合一次性扫描
 * - WebSocket: 被动接收，适合实时监听
 * - WebSocket 更高效，不需要轮询
 *
 * 注意:
 * - 需要支持 WebSocket 的 RPC 端点
 * - 连接断开时需要重连机制
 * - 生产环境应添加错误处理
 */
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
