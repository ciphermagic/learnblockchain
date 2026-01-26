import { createPublicClient, formatEther, publicActions, webSocket } from 'viem';
import { foundry } from 'viem/chains';
import dotenv from 'dotenv';

dotenv.config();

const ERC20_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9';

const main = async () => {
  // 创建公共客户端
  const publicClient = createPublicClient({
    chain: foundry,
    transport: webSocket(process.env.RPC_URL!),
    // transport: http(process.env.RPC_URL!),
  }).extend(publicActions);

  console.log('开始监听 ERC20 转账事件...');

  // 监听 Transfer 事件
  // cast send 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 "transfer(address,uint256)" 0x01BF49D75f2b73A2FDEFa7664AEF22C86c5Be3df 1000000000000000000 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  const unwatch = publicClient.watchEvent({
    address: ERC20_ADDRESS,
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

          // insert sql
          // const sql = `INSERT INTO erc20_transfers (from, to, value, transaction_hash, block_number) VALUES (${log.args.from}, ${log.args.to}, ${log.args.value}, ${log.transactionHash}, ${log.blockNumber})`;
          // console.log(sql);
        }
      });
    },
  });

  // 保持程序运行
  process.on('SIGINT', () => {
    console.log('\n停止监听...');
    unwatch();
    process.exit();
  });
};

main().catch(error => {
  console.error('发生错误:', error);
  process.exit(1);
});
