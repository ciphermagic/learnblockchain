/**
 * Merkle Tree 生成工具
 * 用于生成白名单的 Merkle Root 和 Proof
 *
 * 什么是 Merkle Tree?
 * - Merkle 树是一种二叉哈希树，由Ralph Merkle发明
 * - 叶子节点是数据的哈希值，非叶子节点是其子节点哈希值的组合
 * - 顶部只有一个根哈希（Merkle Root）
 *
 * 在白名单中的应用:
 * - 将所有白名单地址作为叶子节点
 * - 生成 Merkle Root，部署时设置到合约中
 * - 用户claim时，提供从自己地址到根的路径（Proof）
 * - 合约验证Proof是否与根匹配
 *
 * 优点:
 * - 存储效率高：只需存储一个根哈希（32字节）
 * - 隐私保护：不暴露完整白名单
 * - 验证效率高：Proof 只需要 log2(N) 个节点
 *
 * 使用方法:
 * npm install merkletreejs ethers
 * node scripts/generate_merkle_tree.js
 */

import { MerkleTree } from 'merkletreejs';
import { ethers } from 'ethers';
import { writeFileSync } from 'fs';

// ============================================
// 配置区：在这里添加你的白名单地址
// ============================================

// 白名单地址列表
// 这些地址将作为 Merkle 树的叶子节点
// 注意:
// - 地址需要是小写或 checksummed 格式
// - 建议添加足够多的测试地址
// - 第一个地址通常是 Foundry 默认账户，方便测试
const whitelistAddresses = [
  '0x5B38Da6a701c568545dCfcB03FcB875f56beddC4', // 测试地址 1
  '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2', // 测试地址 2
  '0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db', // 测试地址 3
  '0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB', // 测试地址 4
  '0x617F2E2fD72FD9D5503197092aC168c91465E7f2', // 测试地址 5
  '0x17F6AD8Ef982297579C203069C1DbfFE4348c372', // 测试地址 6
  '0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678', // 测试地址 7
  '0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7', // 测试地址 8
  // Foundry 默认账户 #0 (私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
  '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
  // ... 添加更多地址
];

// ============================================
// Merkle Tree 生成逻辑
// ============================================

/**
 * 生成 Merkle 树并返回根哈希和每个地址的 Proof
 * @param {string[]} addresses - 白名单地址数组
 * @returns {object} 包含 root, tree, leaves, proofs 的对象
 *
 * 生成过程:
 * 1. 叶子节点生成: 对每个地址进行双重哈希
 *    - 先将地址打包成 bytes32
 *    - 再用 keccak256 哈希
 *    - 这样可以防止第二原像攻击
 *
 * 2. 树构建: 从底部向上构建
 *    - 每层节点数是上一层的一半
 *    - 每对相邻节点计算父节点: Hash(left || right)
 *    - sortPairs=true 确保左右顺序一致（与合约保持一致）
 *
 * 3. 根哈希: 最顶层的唯一节点
 *    - 这个值将存储在合约中
 *    - 验证时只需比较这个值
 *
 * 4. Proof 生成: 每个叶子节点到根的路径
 *    - 路径长度 = log2(N)，效率很高
 *    - 包含同级的兄弟节点哈希
 */
function generateMerkleTree(addresses) {
  console.log(`\n📋 正在为 ${addresses.length} 个地址生成 Merkle Tree...\n`);

  // 1. 生成叶子节点
  const leaves = addresses.map(addr => {
    // 确保地址格式正确
    const checksummedAddr = ethers.getAddress(addr);
    return ethers.keccak256(ethers.solidityPacked(['address'], [checksummedAddr]));
  });

  console.log('✅ 叶子节点生成完成\n');

  // 2. 构建 Merkle Tree (sortPairs 很重要，要和合约保持一致)
  const tree = new MerkleTree(leaves, ethers.keccak256, { sortPairs: true });

  // 3. 获取 Merkle Root
  const root = tree.getHexRoot();

  console.log('🌳 Merkle Tree 信息:');
  console.log('================================');
  console.log(`Root: ${root}`);
  console.log(`叶子节点数量: ${leaves.length}`);
  console.log(`树的深度: ${Math.ceil(Math.log2(leaves.length))}`);
  console.log('================================\n');

  // 4. 生成每个地址的 proof
  console.log('📜 为每个地址生成 Merkle Proof:\n');

  const proofs = {};
  addresses.forEach((addr, index) => {
    const checksummedAddr = ethers.getAddress(addr);
    const leaf = leaves[index];
    const proof = tree.getHexProof(leaf);

    proofs[checksummedAddr] = proof;

    console.log(`地址 ${index + 1}: ${checksummedAddr}`);
    console.log(`Proof (${proof.length} 个哈希):`);
    proof.forEach((p, i) => {
      console.log(`  [${i}]: ${p}`);
    });
    console.log('');
  });

  return {
    root,
    tree,
    leaves,
    proofs,
  };
}

// ============================================
// 验证功能
// ============================================

/**
 * 验证某个地址的 Merkle Proof 是否有效
 * @param {string} address - 要验证的用户地址
 * @param {string[]} proof - 用户提供的 Merkle Proof
 * @param {string} root - Merkle Root
 * @returns {boolean} 验证是否通过
 *
 * 验证原理:
 * 1. 使用相同的方式计算用户地址的叶子哈希
 * 2. 从叶子开始，沿着 Proof 路径逐层向上哈希
 * 3. 每层使用兄弟节点与当前节点拼接后哈希
 * 4. 最终如果得到的结果等于 root，则验证通过
 *
 * 注意: 这里使用库的验证方法，原理相同
 */
function verifyProof(address, proof, root) {
  const leaf = ethers.keccak256(ethers.solidityPacked(['address'], [address]));
  return MerkleTree.verify(proof, leaf, root, ethers.keccak256, { sortPairs: true });
}

// ============================================
// 主函数
// ============================================

function main() {
  console.log('\n🎯 Merkle Tree 白名单生成器');
  console.log('================================\n');

  // 生成 Merkle Tree
  const { root, proofs } = generateMerkleTree(whitelistAddresses);

  // 验证示例
  console.log('✅ 验证示例:');
  console.log('================================');
  const testAddr = whitelistAddresses[0];
  const testProof = proofs[testAddr];
  const isValid = verifyProof(testAddr, testProof, root);
  console.log(`地址: ${testAddr}`);
  console.log(`验证结果: ${isValid ? '✅ 通过' : '❌ 失败'}\n`);

  // 生成 JSON 文件供前端使用
  const output = {
    root: root,
    total: whitelistAddresses.length,
    proofs: proofs,
    addresses: whitelistAddresses.map(addr => ethers.getAddress(addr)),
  };
  writeFileSync('./merkle_tree_data.json', JSON.stringify(output, null, 2));

  console.log('💾 数据已保存到: ./merkle_tree_data.json');

  // 生成 Solidity 测试代码
  console.log('\n📝 Solidity 设置代码:');
  console.log('================================');
  console.log(`// 在合约中设置 Merkle Root`);
  console.log(`whitelist.setMerkleRoot(${root});\n`);

  console.log('📝 用户验证示例 (Solidity):');
  console.log('================================');
  const exampleAddr = whitelistAddresses[0];
  const exampleProof = proofs[exampleAddr];
  console.log(`// 用户 ${exampleAddr} 的验证代码`);
  console.log(`bytes32[] memory proof = new bytes32[](${exampleProof.length});`);
  exampleProof.forEach((p, i) => {
    console.log(`proof[${i}] = ${p};`);
  });
  console.log(`whitelist.claimWithMerkle(proof);`);
  console.log('');

  console.log('\n✅ 完成！');
}

// ============================================
// 运行
// ============================================

try {
  main();
} catch (error) {
  console.error('❌ 错误:', error.message);
  process.exit(1);
}
