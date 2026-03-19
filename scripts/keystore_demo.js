/**
 * KeyStore 工具演示脚本
 *
 * 本脚本演示了如何使用 KeyStore 格式安全存储以太坊私钥。
 * KeyStore 是一种加密的 JSON 格式，可以安全地存储和备份私钥。
 *
 * KeyStore 格式（V3）：
 * {
 *   "crypto": {
 *     "cipher": "aes-128-ctr",
 *     "cipherparams": { "iv": "..." },
 *     "ciphertext": "...",
 *     "kdf": "scrypt",
 *     "kdfparams": { "dklen": 32, "n": 8192, "r": 8, "p": 1, "salt": "..." },
 *     "mac": "..."
 *   },
 *   "id": "uuid",
 *   "version": 3
 * }
 *
 * 加密流程：
 * 1. 生成随机 salt（32 字节）
 * 2. 使用 scrypt 派生密钥（KDF）
 * 3. 生成随机 IV
 * 4. 使用 AES-128-CTR 加密私钥
 * 5. 计算 MAC 用于验证
 * 6. 组合成 KeyStore JSON
 *
 * 使用方法:
 * 1. 配置 .env 文件中的 PRIVATE_KEY
 * 2. pnpm tsx scripts/keystore_demo.js
 */

import KeystoreUtils from './keystore_utils.js'
import path from 'path'
import dotenv from 'dotenv'

dotenv.config()

/**
 * 主函数：演示 KeyStore 的完整使用流程
 */
async function demo() {
    try {
        // ========== 步骤 1: 获取原始私钥 ==========
        // 从环境变量读取私钥
        // ⚠️ 私钥是最敏感的数据，切勿泄露
        const privateKey = process.env.PRIVATE_KEY
        if (!privateKey) {
            throw new Error('请在 .env 文件中设置 PRIVATE_KEY')
        }
        console.log('原始私钥:', privateKey)

        // ========== 步骤 2: 设置密码和文件路径 ==========
        // 密码用于加密私钥
        // 建议使用强密码，并妥善保管
        const password = '123456'

        // KeyStore 文件保存路径
        const keystorePath = path.join(process.cwd(), '.keys', 'keystore.json')
        console.log('KeyStore 保存路径:', keystorePath)

        // ========== 步骤 3: 加密私钥并生成 KeyStore ==========
        // 使用密码加密私钥，生成 KeyStore 对象
        // 加密过程：
        // 1. 生成随机 salt
        // 2. 使用 scrypt 派生加密密钥
        // 3. 生成随机 IV
        // 4. AES-128-CTR 加密私钥
        // 5. 计算 MAC 验证完整性
        console.log('\n开始加密私钥...')
        const keystore = await KeystoreUtils.encryptPrivateKey(privateKey, password)
        console.log('✅ KeyStore 生成成功')
        console.log('KeyStore 版本:', keystore.version)
        console.log('加密算法:', keystore.crypto.cipher)
        console.log('KDF 算法:', keystore.crypto.kdf)

        // ========== 步骤 4: 保存 KeyStore 文件 ==========
        // 将 KeyStore 保存到文件
        // 建议：
        // - 保存到安全的位置
        // - 备份到多个位置
        // - 不要和密码放在一起
        await KeystoreUtils.saveKeystore(keystore, keystorePath)

        // ========== 步骤 5: 加载 KeyStore 文件 ==========
        // 从文件读取 KeyStore
        console.log('\n开始加载 KeyStore 文件...')
        const loadedKeystore = await KeystoreUtils.loadKeystore(keystorePath)
        console.log('✅ KeyStore 文件加载成功')

        // ========== 步骤 6: 解密私钥 ==========
        // 使用密码解密 KeyStore，恢复原始私钥
        // 如果密码错误，会抛出异常
        console.log('\n开始解密私钥...')
        const decryptedPrivateKey = await KeystoreUtils.decryptPrivateKey(loadedKeystore, password)
        console.log('解密后的私钥:', decryptedPrivateKey)

        // ========== 步骤 7: 验证私钥 ==========
        // 验证解密后的私钥与原始私钥一致
        const isMatch = privateKey === decryptedPrivateKey
        console.log('私钥是否一致:', isMatch ? '✅ 一致' : '❌ 不一致')

        /**
         * KeyStore 安全性说明：
         *
         * 优点：
         * - 密码保护：即使文件泄露，没有密码也无法获取私钥
         * - 标准格式：广泛支持，便于备份和迁移
         * - 抗暴力破解：scrypt 参数可调整，增加破解难度
         *
         * 缺点：
         * - 需要记忆密码：密码丢失无法恢复
         * - 速度较慢：scrypt 计算密集
         *
         * 最佳实践：
         * 1. 使用强密码（包含大小写、数字、特殊字符）
         * 2. 将密码和 KeyStore 文件分开存储
         * 3. 备份多个副本
         * 4. 定期更新密码
         */

        // ========== 演示错误密码的情况 ==========
        console.log('\n========== 测试错误密码 ==========')
        try {
            const wrongPassword = 'wrong_password'
            await KeystoreUtils.decryptPrivateKey(loadedKeystore, wrongPassword)
            console.log('❌ 应该抛出错误但没有')
        } catch (error) {
            console.log('✅ 错误密码正确触发异常:', error instanceof Error ? error.message : '未知错误')
        }

    } catch (error) {
        console.error('演示过程出错:', error)
    }
}

// 执行演示
demo()

/**
 * 与钱包的集成：
 *
 * 大多数以太坊钱包（MetaMask, Ledger, Trezor 等）都支持 KeyStore 格式：
 * - 导入：可以将 KeyStore 导入钱包
 * - 导出：可以将钱包私钥导出为 KeyStore
 * - 备份：KeyStore 是安全的备份格式
 *
 * 与其他格式的对比：
 *
 * | 格式     | 安全性 | 便利性 | 适用场景         |
 * |----------|--------|--------|------------------|
 * | KeyStore | ⭐⭐⭐   | ⭐⭐    | 长期存储、备份    |
 * | 助记词   | ⭐⭐⭐   | ⭐⭐⭐   | 钱包恢复、多账户   |
 * | 私钥     | ⭐⭐     | ⭐⭐⭐   | 快速测试、单次使用 |
 * | Keystore | ⭐⭐⭐   | ⭐⭐    | 程序化交易、安全存储 |
 */
