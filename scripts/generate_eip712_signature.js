/**
 * EIP-712 签名生成工具
 * 用于为白名单用户生成签名
 *
 * EIP-712 是一种以太坊改进提案，定义了一种结构化数据的签名标准
 * 与普通以太坊签名不同，EIP-712 签名包含了具体的数据结构，使得签名更加安全和用户友好
 *
 * 使用方法:
 * npm install ethers
 * node scripts/generate_eip712_signature.js
 *
 * 核心概念:
 * - Domain: 定义签名的域信息，包括合约名称、版本、链ID等
 * - Types: 定义签名的数据结构
 * - Value: 要签名的具体数据
 *
 * 安全性提示:
 * - 签名具有时效性（通过 expiry 参数控制）
 * - 每个用户有唯一的 nonce，防止重放攻击
 * - 签名者地址应该与合约部署者地址一致
 */

import fs from 'fs';
import { ethers } from 'ethers';

// ============================================
// 配置区 - 在此修改相关配置
// ============================================

// 签名者私钥（这是测试私钥，不要在生产环境使用！）
// 在生产环境中，应该使用 HSM（硬件安全模块）或者安全的密钥管理服务
// 这里使用的是 Foundry/Anvil 默认的第一个测试账户私钥
// 实际使用时替换为你的签名者私钥（需要带 0x 前缀）

const SIGNER_PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; //  测试账户 #0

// 合约地址（部署后填入）
const CONTRACT_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // 替换为你的合约地址

// 链 ID
// 常见链 ID:
// 1 = Ethereum Mainnet (主网)
// 5 = Goerli Testnet (测试网，已弃用)
// 11155111 = Sepolia Testnet (当前推荐的测试网)
// 31337 = Anvil/Foundry 本地测试网络
// 42161 = Arbitrum One
// 10 = Optimism
const CHAIN_ID = 31337; // 本地测试网，生产环境需要改为 1 (主网) 或 11155111 (Sepolia)

// 要签名的用户地址列表
const USERS_TO_SIGN = [
  '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
  '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
  '0x90F79bf6EB2c4f870365E785982E1f101E93b906',
];

// ============================================
// EIP-712 Domain 和 Types 定义
// ============================================

// Domain Separator (域分隔符)
// 用于确保签名只能在特定的合约和链上使用，防止跨链重放攻击
const domain = {
  name: 'Whitelist', // 合约名称，需要与合约中定义的一致
  version: '1.0.0', // 合约版本号
  chainId: CHAIN_ID, // 链 ID，防止跨链重放攻击
  verifyingContract: CONTRACT_ADDRESS, // 验证签名的合约地址
};

// Types (类型定义)
// 定义签名的数据结构，类似于 TypeScript 接口
// 这里定义了一个 WhitelistRequest 类型，包含三个字段:
// - user: 要白名单的用户地址
// - nonce: 随机数，防止重放攻击
// - expiry: 过期时间戳，过期后签名无效
const types = {
  WhitelistRequest: [
    { name: 'user', type: 'address' }, // 用户地址
    { name: 'nonce', type: 'uint256' }, // 随机数，建议使用合约中的 nonce
    { name: 'expiry', type: 'uint256' }, // 过期时间戳（Unix 时间戳，单位：秒）
  ],
};

// ============================================
// 签名生成函数
// ============================================

/**
 * 为指定用户生成 EIP-712 签名
 * @param {string} userAddress - 用户的钱包地址（0x 开头）
 * @param {number} nonce - 用户当前的 nonce 值（从合约查询，防止重放攻击）
 * @param {number} expiryHours - 签名有效期的小时数
 * @returns {Promise<object>} 包含签名数据的对象
 *
 * 工作原理:
 * 1. 使用 ethers.Wallet 创建签名者
 * 2. 计算过期时间（当前时间 + 有效期）
 * 3. 构建要签名的数据结构
 * 4. 使用 signTypedData 方法进行 EIP-712 签名
 *
 * 签名算法:
 * - 先对数据进行哈希，生成 digest
 * - 然后用私钥对 digest 进行签名
 * - 最终得到 65 字节的签名（r, s, v）
 */
async function generateSignature(userAddress, nonce = 0, expiryHours = 24) {
  // 创建签名者
  const signer = new ethers.Wallet(SIGNER_PRIVATE_KEY);

  // 计算过期时间
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const expiry = currentTimestamp + expiryHours * 3600;

  // 准备数据
  const value = {
    user: userAddress,
    nonce: nonce,
    expiry: expiry,
  };

  // 签名
  const signature = await signer.signTypedData(domain, types, value);

  return {
    user: userAddress,
    nonce: nonce,
    expiry: expiry,
    expiryDate: new Date(expiry * 1000).toISOString(),
    signature: signature,
    signerAddress: signer.address,
  };
}

// ============================================
// 验证签名函数
// ============================================

/**
 * 验证 EIP-712 签名的有效性
 * 通过恢复签名者的地址来验证签名
 * @param {object} signatureData - 包含 user, nonce, expiry, signature 的对象
 * @returns {string} 恢复出的签名者地址
 *
 * 验证原理:
 * - EIP-712 签名是基于椭圆曲线的签名
 * - 给定签名数据，可以通过数学方法恢复出签名者的公钥/地址
 * - 如果恢复的地址与签名者地址一致，则说明签名有效
 *
 * 注意: 这里只验证签名本身的有效性
 * 实际的业务验证（如检查 nonce、expiry）需要在合约中进行
 */
function verifySignature(signatureData) {
  const { user, nonce, expiry, signature } = signatureData;

  // 重新构建消息
  const value = {
    user: user,
    nonce: nonce,
    expiry: expiry,
  };

  // 恢复签名者地址
  const recovered = ethers.verifyTypedData(domain, types, value, signature);

  return recovered.toLowerCase();
}

// ============================================
// 主函数
// ============================================

async function main() {
  console.log('\n🔐 EIP-712 签名生成器');
  console.log('================================\n');

  console.log('⚙️  配置信息:');
  console.log(`合约地址: ${CONTRACT_ADDRESS}`);
  console.log(`链 ID: ${CHAIN_ID}`);

  const signer = new ethers.Wallet(SIGNER_PRIVATE_KEY);
  console.log(`签名者地址: ${signer.address}\n`);

  // 为每个用户生成签名
  const signatures = [];

  console.log('📝 生成签名:\n');

  for (let i = 0; i < USERS_TO_SIGN.length; i++) {
    const userAddress = USERS_TO_SIGN[i];
    const signatureData = await generateSignature(userAddress, 0, 24);
    signatures.push(signatureData);

    console.log(`用户 ${i + 1}: ${userAddress}`);
    console.log(`  Nonce: ${signatureData.nonce}`);
    console.log(`  过期时间: ${signatureData.expiryDate}`);
    console.log(`  签名: ${signatureData.signature}`);

    // 验证签名
    const recoveredSigner = verifySignature(signatureData);
    const isValid = recoveredSigner.toLowerCase() === signer.address.toLowerCase();
    console.log(`  验证: ${isValid ? '✅ 通过' : '❌ 失败'} (恢复的地址: ${recoveredSigner})\n`);
  }

  // 保存到 JSON 文件
  const output = {
    domain: domain,
    types: types,
    signatures: signatures,
    generatedAt: new Date().toISOString(),
  };
  fs.writeFileSync('./eip712_signatures.json', JSON.stringify(output, null, 2));

  console.log('💾 签名数据已保存到: ./eip712_signatures.json\n');

  // 生成前端调用示例
  console.log('📝 前端使用示例 (JavaScript/ethers.js):');
  console.log('================================');
  console.log(`
const signature = "${signatures[0].signature}";
const nonce = ${signatures[0].nonce};
const expiry = ${signatures[0].expiry};

// 调用合约
const tx = await whitelistContract.claimWithEIP712(
    nonce,
    expiry,
    signature
);

await tx.wait();
console.log("✅ 领取成功！");
`);

  // 生成 Solidity 测试代码
  console.log('\n📝 Solidity 测试代码:');
  console.log('================================');
  console.log(`
address user = ${signatures[0].user};
uint256 nonce = ${signatures[0].nonce};
uint256 expiry = ${signatures[0].expiry};
bytes memory signature = hex"${signatures[0].signature.slice(2)}";

vm.prank(user);
whitelist.claimWithEIP712(nonce, expiry, signature);
`);

  // 生成 cast 命令示例
  console.log('\n📝 使用 cast 调用合约:');
  console.log('================================');
  console.log(`
cast send ${CONTRACT_ADDRESS} \\
  "claimWithEIP712(uint256,uint256,bytes)" \\
  ${signatures[0].nonce} \\
  ${signatures[0].expiry} \\
  "${signatures[0].signature}" \\
  --rpc-url http://localhost:8545 \\
  --private-key <USER_PRIVATE_KEY>
`);

  console.log('\n✅ 完成！');
}

// ============================================
// 辅助函数：为后端 API 使用
// ============================================

/**
 * 后端 API 可以调用这个函数为用户生成签名
 * @param {string} userAddress - 用户地址
 * @param {number} currentNonce - 用户当前的 nonce（从链上查询）
 * @param {number} expiryHours - 签名有效期（小时）
 * @returns {Promise<object>} 签名数据
 */
async function generateSignatureForAPI(userAddress, currentNonce, expiryHours = 1) {
  return await generateSignature(userAddress, currentNonce, expiryHours);
}

/**
 * Express.js API 端点示例
 */
function expressAPIExample() {
  console.log(`
// Express.js 后端示例

const express = require('express');
const app = express();
app.use(express.json());

// 获取签名的 API 端点
app.post('/api/whitelist/signature', async (req, res) => {
    try {
        const { userAddress } = req.body;
        
        // 验证用户是否在白名单中（从数据库查询）
        const isWhitelisted = await checkIfWhitelisted(userAddress);
        if (!isWhitelisted) {
            return res.status(403).json({ error: 'Not whitelisted' });
        }
        
        // 从链上查询用户的当前 nonce
        const currentNonce = await contract.nonces(userAddress);
        
        // 生成签名
        const signatureData = await generateSignatureForAPI(
            userAddress,
            currentNonce,
            1 // 1小时有效期
        );
        
        res.json(signatureData);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.listen(3000, () => {
    console.log('API server running on port 3000');
});
`);
}

// ============================================
// 运行
// ============================================

main().catch(error => {
  console.error('❌ 错误:', error);
  process.exit(1);
});
