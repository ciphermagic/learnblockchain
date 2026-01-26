import { privateKeyToAccount } from 'viem/accounts';
import { generateMnemonic, mnemonicToSeedSync } from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';
import { HDKey } from '@scure/bip32';
import { Buffer } from 'node:buffer';

// 生成助记词
// const mnemonic = generateMnemonic(wordlist);
const mnemonic = 'trumpet subject sunny situate animal night pelican blur aisle weather sorry matrix';
console.log('助记词：', mnemonic);

// 派生私钥
const seed = mnemonicToSeedSync(mnemonic); // 助记词 → 种子
const hdKey = HDKey.fromMasterSeed(seed); // 种子 → 主 HD 密钥
const child = hdKey.derive("m/44'/60'/0'/0/1"); // 派生路径（第 1 个地址）

// 检查并确保私钥存在
if (!child.privateKey) {
  throw new Error('无法生成私钥');
}

// 确保私钥是正确的十六进制格式
const privateKeyBuffer = Buffer.from(child.privateKey.slice(0, 32));
const privateKeyHex = `0x${privateKeyBuffer.toString('hex')}` as `0x${string}`;

console.log('私钥：', privateKeyHex, '长度:', privateKeyHex.length - 2, '字节:', (privateKeyHex.length - 2) / 2);

// 从私钥创建账户
const account = privateKeyToAccount(privateKeyHex);
console.log('地址:', account.address, '长度:', account.address.length - 2, '字节:', (account.address.length - 2) / 2);
console.log('公钥（未压缩）：', account.publicKey);
