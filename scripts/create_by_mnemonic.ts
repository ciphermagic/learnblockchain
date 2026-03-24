/**
 * 通过助记词创建账户脚本
 *
 * 本脚本演示了如何使用 BIP39 助记词标准创建以太坊账户。
 * 助记词是一种人类可读的种子短语，可以用于恢复钱包和派生多个账户。
 *
 * BIP39 流程：
 * 1. 生成随机熵（128-256 位）
 * 2. 熵 + 校验和 = 助记词（12/24 个单词）
 * 3. 助记词 -> 种子（PBKDF2）
 * 4. 种子 -> 主密钥 -> 子密钥（ BIP32/BIP44）
 *
 * 使用方法:
 * pnpm tsx scripts/create_by_mnemonic.ts
 *
 * 助记词路径标准（ BIP44 ）:
 * m/44'/60'/0'/0/0  - 第一个以太坊账户
 * m/44'/60'/0'/0/1  - 第二个以太坊账户
 *
 * 60 是以太坊的 Coin Type
 */

import { privateKeyToAccount } from 'viem/accounts';
import { HDKey } from '@scure/bip32';
import { Buffer } from 'node:buffer';
import { mnemonicToSeedSync } from '@scure/bip39';
import { keccak256 } from 'viem';

// ========== 步骤 1: 使用助记词 ==========
// 这里使用固定的助记词用于演示
// 助记词应该是安全的，不要硬编码在生产代码中
const mnemonic = 'trumpet subject sunny situate animal night pelican blur aisle weather sorry matrix';
console.log('助记词：', mnemonic);

/**
 * 助记词安全性说明：
 * ⚠️ 助记词是钱包的"主密钥"，一旦丢失无法恢复！
 * ⚠️ 不要将助记词存储在代码、截图，云笔记等不安全的地方
 * ⚠️ 建议手写在纸上，存放在安全的地方
 *
 * 助记词强度：
 * - 12 个单词：128 位熵 + 4 位校验和 = 128 位安全
 * - 24 个单词：256 位熵 + 8 位校验和 = 256 位安全
 */

// ========== 步骤 2: 将助记词转换为种子 ==========

// mnemonicToSeedSync 将助记词转换为 64 字节的种子
// 内部使用 PBKDF2 算法（2048 轮迭代 + 可选密码）
// 种子 = PBKDF2(mnemonic, "mnemonic" + 可选密码, 2048, 64, 'sha512')
const seed = mnemonicToSeedSync(mnemonic);

const hash = keccak256(seed);
console.log('种子（哈希）：', hash);

// ========== 步骤 3: 从种子派生主 HD 密钥 ==========

// HDKey.fromMasterSeed 从种子创建主密钥
// 这遵循 BIP32 标准，主密钥是树的根
const hdKey = HDKey.fromMasterSeed(Buffer.from(seed));

// ========== 步骤 4: 派生子密钥 ==========

// derive 方法根据路径派生子密钥
// 路径格式：m/44'/60'/0'/0/0
// - m: 主密钥
// - 44': BIP44 目的
// - 60': 以太坊（coin type）
// - 0': 账户级别（ hardened ）
// - 0: 外部链（0 = 外部，1 = 内部）
// - 0: 第一个地址索引

/**
 * BIP44 路径层级说明：
 * m / purpose' / coin_type' / account' / change / address_index
 *
 * purpose': 44' 表示 BIP44 标准
 * coin_type': 60' 表示以太坊
 *   - 0: Bitcoin
 *   - 60: Ethereum
 *   - 8453: Base
 *   - 2147483647: Optimism
 * account': 账户编号（从 0 开始）
 * change: 0 = 外部链（接收地址），1 = 内部链（找零地址）
 * address_index: 地址索引（从 0 开始）
 */

// 派生第一个以太坊账户
const child = hdKey.derive("m/44'/60'/0'/0/1");

// ========== 步骤 5: 验证私钥生成 ==========

// 检查私钥是否成功生成
if (!child.privateKey) {
  throw new Error('无法生成私钥');
}

// ========== 步骤 6: 转换为以太坊格式 ==========

// Buffer 用于处理二进制数据
// 私钥必须是 32 字节
const privateKeyBuffer = Buffer.from(child.privateKey.slice(0, 32));

// 转换为十六进制字符串（带 0x 前缀）
const privateKeyHex = `0x${privateKeyBuffer.toString('hex')}` as `0x${string}`;

console.log('私钥：', privateKeyHex);
console.log(`私钥长度: ${privateKeyHex.length - 2} 字符 / ${(privateKeyHex.length - 2) / 2} 字节`);

// ========== 步骤 7: 从私钥创建以太坊账户 ==========

// privateKeyToAccount 是 viem 提供的便捷函数
// 它会从私钥推导出地址和公钥
const account = privateKeyToAccount(privateKeyHex);

console.log('地址:', account.address);
console.log(`地址长度: ${account.address.length - 2} 字符 / ${(account.address.length - 2) / 2} 字节`);
console.log('公钥（未压缩）：', account.publicKey);

/**
 * 账户信息说明：
 * - 地址：以太坊账户的唯一标识（20 字节）
 * - 公钥：由私钥通过椭圆曲线（secp256k1）派生
 * - 私钥：账户的控制权凭证（32 字节）
 */

// ========== HD 钱包的优势 ==========
/*
 * 1. 🌱 单一种子：只需备份助记词，即可恢复所有账户
 * 2. 🔒 安全性：私钥不暴露在内存中，按需派生
 * 3. 📊 确定性：同一助记词总是派生相同地址
 * 4. 🔢 多个地址：一个种子可派生无限多个账户
 * 5. 💼 兼容性：遵循行业标准（BIP39/32/44）
 */

/**
 * 常见路径示例：
 * m/44'/60'/0'/0/0   - 第一个 ETH 账户
 * m/44'/60'/0'/0/1   - 第二个 ETH 账户
 * m/44'/60'/0'/0/2   - 第三个 ETH 账户
 *
 * m/44'/60'/0'/0/0   - 第一个 ETH 账户（Legacy）
 * m/44'/60'/0'/0/0   - 第一个 ETH 账户（Ledger Live）
 * m/44'/60'/1'/0/0   - 第一个 ETH 账户（MetaMask）
 *
 * m/44'/8453'/0'/0/0 - 第一个 Base 账户（不同链）
 */
