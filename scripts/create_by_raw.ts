/**
 * 通过私钥直接创建账户脚本
 *
 * 本脚本演示了如何使用 viem 库直接通过私钥创建以太坊账户。
 * 这是最简单直接的账户创建方式，适用于测试和快速原型开发。
 *
 * 工作原理：
 * 1. generatePrivateKey() 生成一个随机的 32 字节私钥
 * 2. privateKeyToAccount() 从私钥推导出以太坊地址和公钥
 *
 * 使用方法:
 * pnpm tsx scripts/create_by_raw.ts
 */

import { generatePrivateKey, privateKeyToAccount } from 'viem/accounts';

/**
 * 生成一个新的随机私钥
 * generatePrivateKey() 会生成一个符合以太坊标准的 32 字节随机私钥
 * 以太坊私钥是一个 256 位的随机数，通常表示为 64 位十六进制字符串（不含 0x 前缀）
 */
const privateKey = generatePrivateKey();
console.log('私钥:', privateKey, '长度:', privateKey.length - 2, '字节:', (privateKey.length - 2) / 2);

/**
 * 从私钥创建账户对象
 * privateKeyToAccount 会解析私钥并生成对应的以太坊地址和公钥
 * 这个过程涉及到椭圆曲线密码学（secp256k1）
 *
 * 返回的 account 对象包含：
 * - address: 以太坊地址（20 字节，40 位十六进制）
 * - publicKey: 公钥（未压缩格式为 65 字节，压缩格式为 33 字节）
 * - source: 账户来源类型
 * - signMessage: 签名消息方法
 * - signTransaction: 签名交易方法
 */
const account = privateKeyToAccount(privateKey);
console.log('地址:', account.address, '长度:', account.address.length - 2, '字节:', (account.address.length - 2) / 2);
console.log('公钥（未压缩）:', account.publicKey);

/**
 * 注意事项：
 * 1. 私钥是账户安全的核心，切勿泄露给他人
 * 2. 每次运行此脚本都会生成新的随机私钥
 * 3. 如果需要恢复已有账户，请使用助记词（mnemonic）方式
 * 4. 生成的私钥请妥善保存，否则无法恢复账户
 */
