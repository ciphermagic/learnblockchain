/**
 * 签名与验证演示脚本
 *
 * 本脚本演示了如何使用 viem 库进行以太坊消息签名和验证（EIP-191）。
 * 这是实现 Web3 身份认证（Sign-In with Ethereum）的基础。
 *
 * 工作原理：
 * 1. 使用私钥对消息进行签名
 * 2. 使用签名验证消息确实来自对应地址
 * 3. 在 Solidity 合约中可以使用 ecrecover 恢复签名者地址
 *
 * 使用方法:
 * pnpm tsx scripts/sign_verify.ts
 */

import { verifyMessage, hashMessage } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

/**
 * 主函数：演示签名和验证流程
 */
async function main() {
  // ========== 步骤 1: 创建账户 ==========
  // 使用测试私钥创建账户（这是 Anvil/Hardhat 默认的第一个账户）
  // 在生产环境中，私钥应该从安全存储（如钱包、HSM）获取
  const privateKey = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
  const account = privateKeyToAccount(privateKey);

  console.log('钱包地址:', account.address);

  // ========== 步骤 2: 准备要签名的消息 ==========
  // 可以是任意字符串
  const message = 'hello world';
  console.log('待签名消息:', message);

  // ========== 步骤 3: 计算消息哈希 ==========
  // hashMessage 会对消息进行 Ethereum Signed Message 前缀处理
  // 这确保签名的消息不会与其他用途的消息混淆
  // 处理方式：keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
  const hash = await hashMessage(message);
  console.log('消息哈希:', hash);

  // ========== 步骤 4: 使用账户签名消息 ==========
  // signMessage 使用 EOA 私钥对消息进行 ECDSA 签名
  // 返回值是 65 字节的签名：r || s || v（v 为 27 或 28）
  const signature = await account.signMessage({
    message,
  });
  console.log('签名结果:', signature);

  // ========== 步骤 5: 验证签名 ==========
  // verifyMessage 用于验证签名是否有效
  // 它会从签名中恢复出签名者的地址，并与提供的地址进行比较
  const isValid = await verifyMessage({
    address: account.address,
    message: 'hello world',
    signature,
  });

  // 输出验证结果
  console.log('签名验证结果:', isValid ? '✅ 验证成功' : '❌ 验证失败');

  // ========== 步骤 6: 在 Solidity 中验证（原理说明） ==========
  // Solidity 合约中验证签名的标准方式：
  /*
  contract SignatureVerifier {
      function recover(bytes memory message, bytes memory signature) public pure returns (address) {
          // 1. 计算 Ethereum Signed Message 哈希
          bytes32 hash = MessageHashUtils.toEthSignedMessageHash(message);

          // 2. 使用 ecrecover 恢复签名者地址
          return ECDSA.recover(hash, signature);
      }

      function verify(bytes memory message, bytes memory signature, address signer) public pure returns (bool) {
          return recover(message, signature) == signer;
      }
  }
  */

  // ========== 签名算法说明 ==========
  // 以太坊签名使用 ECDSA（椭圆曲线数字签名算法）
  // 曲线：secp256k1（与比特币相同）
  //
  // 签名过程：
  // 1. 对消息进行哈希（使用 hashMessage 添加前缀）
  // 2. 使用私钥对哈希进行签名
  // 3. 得到 r, s, v 三个值，组合成最终签名
  //
  // 验证过程：
  // 1. 同样对消息进行哈希
  // 2. 使用签名的 r, s 和 v 恢复公钥
  // 3. 从公钥计算出地址，与签名者地址比较
}

/**
 * 签名的应用场景：
 *
 * 1. 🏷️ 身份认证 (SIWE - Sign-In with Ethereum)
 *    用户通过签名消息证明自己拥有某个地址的所有权
 *
 * 2. 📝 授权确认
 *    链下签名授权某个操作，如白名单、预售等
 *
 * 3. 🔐 权限验证
 *    多签钱包、代理合约等场景下的操作授权
 *
 * 4. 📋 预言机数据
 *    Chainlink 等预言机使用签名来认证数据源
 *
 * ⚠️ 安全注意事项：
 * 1. 签名消息应该包含足够的信息防止重放攻击
 * 2. 使用 nonce（随机数）确保每条消息只能使用一次
 * 3. 设置过期时间，防止签名被长期滥用
 * 4. 不要签名包含敏感操作的消息
 */

// 运行主函数
main().catch(error => {
  console.error('发生错误:', error);
  process.exit(1);
});
