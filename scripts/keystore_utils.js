import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';

/**
 * KeyStore 工具类
 *
 * 什么是 KeyStore?
 * - KeyStore 是一种加密存储私钥的文件格式
 * - 最初由 Ethereum Wallet (Mist) 引入
 * - 版本 3 是最常用的格式（JSON 格式）
 *
 * 安全性原理:
 * - 用户需要提供一个密码
 * - 使用 scrypt 密钥派生函数从密码生成加密密钥
 * - 使用 AES-128-CTR 加密私钥
 * - 使用 SHA3-256 计算 MAC 验证密码正确性
 *
 * 与私钥文件的区别:
 * - 私钥文件: 纯文本，不安全
 * - KeyStore: 需要密码才能解密，相对安全
 *
 * 使用场景:
 * - 钱包备份（冷钱包）
 * - 多签钱包的密钥管理
 * - 需要安全存储私钥的应用
 */
class KeystoreUtils {
  /**
   * 加密私钥并生成 KeyStore 文件
   * @param {string} privateKey - 私钥（带0x前缀）
   * @param {string} password - 密码
   * @returns {Object} KeyStore 对象
   *
   * 加密流程详解:
   *
   * 1. Salt (盐) - 32字节随机数
   *    - 作用: 防止彩虹表攻击
   *    - 每个 KeyStore 都有唯一的 salt
   *    - 存储在 KeyStore 文件中（不保密）
   *
   * 2. Scrypt 密钥派生
   *    - N=8192: CPU/内存成本参数 (2^13 = 8192)
   *    - r=8: 块大小参数
   *    - p=1: 并行参数
   *    - dklen=32: 输出密钥长度（32字节 = 256位）
   *    - 派生出一个 32 字节的密钥
   *    - 前16字节用于 AES 加密
   *    - 后16字节用于 MAC 验证
   *
   * 3. IV (初始化向量) - 16字节随机数
   *    - 作用: 确保相同明文产生不同密文
   *    - 每次加密都应该使用新的 IV
   *
   * 4. AES-128-CTR 加密
   *    - AES-128: 128位密钥（使用派生密钥的前16字节）
   *    - CTR: 计数器模式，允许并行加密
   *    - 加密私钥（32字节）
   *
   * 5. MAC (消息认证码)
   *    - 使用 SHA3-256 哈希算法
   *    - 输入: derivedKey[16:32] + ciphertext
   *    - 作用: 验证密码是否正确 + 检测密文是否被篡改
   */
  static async encryptPrivateKey(privateKey, password) {
    try {
      // 1. 生成随机 salt (32字节)
      // salt 应该足够随机以防止彩虹表攻击
      const salt = crypto.randomBytes(32);

      // 2. 使用 scrypt 派生密钥 (32字节)
      // scrypt 是内存硬的密钥派生函数，能有效防止 GPU 攻击
      const derivedKey = crypto.scryptSync(password, salt, 32, {
        N: 8192, // CPU 成本
        r: 8, // 内存块大小
        p: 1, // 并行度
      });

      // 3. 生成 IV (16字节)
      // 初始化向量，确保加密随机性
      const iv = crypto.randomBytes(16);

      // 4. 加密私钥
      // 使用派生密钥的前16字节作为 AES-128 的密钥
      // CTR 模式允许并行处理，加密效率高
      const cipher = crypto.createCipheriv('aes-128-ctr', derivedKey.slice(0, 16), iv);
      const privateKeyBuffer = Buffer.from(privateKey.slice(2), 'hex'); // 移除 0x 前缀
      const ciphertext = Buffer.concat([cipher.update(privateKeyBuffer), cipher.final()]);

      // 5. 计算 MAC (消息认证码)
      // 使用 SHA3-256 哈希
      // 输入 = 派生密钥的后16字节 + 密文
      // 这样可以同时验证密码正确性和密文完整性
      const mac = crypto
        .createHash('sha3-256')
        .update(Buffer.concat([derivedKey.slice(16, 32), ciphertext]))
        .digest();

      // 6. 返回 KeyStore 对象 (JSON 格式，版本 3)
      // 包含所有解密所需的信息（除了密码）
      return {
        crypto: {
          cipher: 'aes-128-ctr',
          cipherparams: { iv: iv.toString('hex') },
          ciphertext: ciphertext.toString('hex'),
          kdf: 'scrypt',
          kdfparams: {
            dklen: 32,
            n: 8192,
            p: 1,
            r: 8,
            salt: salt.toString('hex'),
          },
          mac: mac.toString('hex'),
        },
        id: crypto.randomUUID(),
        version: 3,
      };
    } catch (error) {
      console.error('加密私钥失败:', error);
      throw error;
    }
  }

  /**
   * 从 KeyStore 文件解密私钥
   * @param {Object} keystore - KeyStore 对象
   * @param {string} password - 密码
   * @returns {string} 解密后的私钥（带0x前缀）
   *
   * 解密流程详解:
   *
   * 1. 读取 KeyStore 参数
   *    - 从 JSON 中提取 salt, iv, ciphertext, mac
   *    - 提取 scrypt 参数 (N, r, p)
   *
   * 2. 重新派生密钥
   *    - 使用相同的密码和 salt 重新运行 scrypt
   *    - 必须得到与加密时相同的派生密钥
   *
   * 3. 验证 MAC (关键安全步骤)
   *    - 使用派生密钥后16字节 + 密文 计算 MAC
   *    - 与存储的 MAC 比较
   *    - 如果不匹配，说明密码错误或文件被篡改
   *    - 这是防止穷举攻击的重要保护
   *
   * 4. 解密私钥
   *    - 使用派生密钥前16字节作为 AES-128 密钥
   *    - 使用相同的 IV 解密
   *    - 恢复原始私钥
   */
  static async decryptPrivateKey(keystore, password) {
    try {
      const { crypto: cryptoData } = keystore;

      // 1. 从 KeyStore 获取加密参数
      const { kdfparams, cipherparams, ciphertext, mac } = cryptoData;
      const { salt } = kdfparams;
      const { iv } = cipherparams;

      // 2. 使用 scrypt 重新派生密钥
      // 必须使用与加密时相同的参数
      const derivedKey = crypto.scryptSync(password, Buffer.from(salt, 'hex'), kdfparams.dklen, {
        N: kdfparams.n,
        r: kdfparams.r,
        p: kdfparams.p,
      });

      // 3. 验证 MAC (消息认证码)
      // 这是安全的关键步骤:
      // - 如果密码错误，派生密钥不同，MAC 不匹配
      // - 如果密文被篡改，MAC 不匹配
      const calculatedMac = crypto
        .createHash('sha3-256')
        .update(Buffer.concat([derivedKey.slice(16, 32), Buffer.from(ciphertext, 'hex')]))
        .digest();

      // 如果 MAC 不匹配，抛出错误（不透露具体原因，防止枚举攻击）
      if (calculatedMac.toString('hex') !== mac) {
        throw new Error('密码错误或 KeyStore 文件已损坏');
      }

      // 4. 解密私钥
      // 使用 AES-128-CTR 解密
      const decipher = crypto.createDecipheriv(
        'aes-128-ctr',
        derivedKey.slice(0, 16), // 使用派生密钥的前16字节
        Buffer.from(iv, 'hex'),
      );

      const decrypted = Buffer.concat([decipher.update(Buffer.from(ciphertext, 'hex')), decipher.final()]);

      // 返回带 0x 前缀的私钥
      return '0x' + decrypted.toString('hex');
    } catch (error) {
      console.error('解密私钥失败:', error);
      throw error;
    }
  }

  /**
   * 保存 KeyStore 文件
   * @param {Object} keystore - KeyStore 对象
   * @param {string} filePath - 保存路径
   */
  static async saveKeystore(keystore, filePath) {
    try {
      // 确保目录存在
      await fs.mkdir(path.dirname(filePath), { recursive: true });

      await fs.writeFile(filePath, JSON.stringify(keystore, null, 2), 'utf8');
      console.log('KeyStore 文件已保存到:', filePath);
    } catch (error) {
      console.error('保存 KeyStore 文件失败:', error);
      throw error;
    }
  }

  /**
   * 加载 KeyStore 文件
   * @param {string} filePath - KeyStore 文件路径
   * @returns {Object} KeyStore 对象
   */
  static async loadKeystore(filePath) {
    try {
      const data = await fs.readFile(filePath, 'utf8');
      return JSON.parse(data);
    } catch (error) {
      console.error('加载 KeyStore 文件失败:', error);
      throw error;
    }
  }
}

export default KeystoreUtils;
