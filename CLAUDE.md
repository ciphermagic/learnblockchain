# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个全栈 Web3 学习与实战项目，名为 "Learn Blockchain"（内部项目名：simple-viem），覆盖智能合约开发、前端 DApp 交互、链上操作脚本三大核心领域。项目使用 Next.js 作为前端框架，Foundry 作为智能合约开发工具集，以及 Viem 和 Wagmi 作为 Web3 交互库。

## 环境要求

- **Node.js**: >= 18
- **pnpm**: >= 8
- **Foundry**: 最新版本（包含 forge, cast, anvil）

## 技术栈

- **智能合约**: Solidity 0.8.20+, Foundry, OpenZeppelin Contracts
- **前端**: Next.js 16 (canary), TypeScript, viem 2.x, wagmi 2.x, Tailwind CSS 4
- **钱包连接**: Reown AppKit
- **包管理**: pnpm

## 项目架构

### 智能合约模块 (contracts/)
- 使用 Foundry 工具集开发 Solidity 智能合约
- 支持升级合约（UUPS 代理模式）
- 合约类型包括：ERC-20/ERC-721 代币、NFT 市场、多签钱包、签名验证等
- 依赖管理通过 remappings.txt 配置

### 前端模块 (app/)
- Next.js 14 应用，采用 App Router 架构
- NFT 市场前端位于 app/nft-market/
- 提供多个交互组件（erc20、siwe、tokenbank、viem-counter 等）

### 工具脚本 (scripts/)
- 交易构建脚本（原始交易、Keystore、EIP-7702 授权等）
- 签名和验证脚本
- 监控脚本（ERC20/ETH 转账监听）

## 常用命令

### 合约开发
```bash
# 编译合约
cd contracts && forge build

# 运行所有测试
cd contracts && forge test

# 运行单个测试（按函数名匹配）
cd contracts && forge test --match-test TestFunctionName

# 运行单个测试（按合约名匹配）
cd contracts && forge test --match-contract CounterTest

# 运行测试并显示详细输出
cd contracts && forge test -vvv

# 查看 gas 使用情况
cd contracts && forge test --gas-report

# 生成 ABI 文件（前端开发必需）
cd contracts && forge inspect Counter abi --json > ../abis/Counter.json

# 启动本地测试节点
anvil

# 部署到本地节点（需要先启动 anvil）
cd contracts && forge script script/Counter.s.sol:CounterScript --rpc-url http://localhost:8545 --broadcast

# 部署到测试网/主网（需要配置环境变量）
cd contracts && forge script script/Counter.s.sol:CounterScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

# 安装合约依赖（必须使用 --no-git）
cd contracts && forge install --no-git https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable@v5.5.0
```

### 前端开发
```bash
# 安装依赖
pnpm install

# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build

# 运行 linter
pnpm lint
```

### 脚本执行
```bash
# 运行演示脚本
pnpm tsx scripts/index.ts

# 运行特定脚本
pnpm tsx scripts/scanERC20Transfers.ts

# 运行交易模拟
pnpm tsx scripts/simulator_example.ts
```

## 重要配置文件

- `contracts/foundry.toml`: Foundry 配置，包含优化设置、RPC 端点
- `contracts/remappings.txt`: Solidity 导入路径映射
- `package.json`: 前端依赖和脚本配置
- `.env`: 环境变量配置（需要配置 RPC_URL、PRIVATE_KEY 等）
- `abis/`: ABI 文件存放目录，前端通过这些文件与合约交互

## 环境变量配置

项目需要在根目录创建 `.env` 文件，包含以下变量：

```bash
# RPC 端点
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# 部署账户私钥（不要提交到 git）
PRIVATE_KEY=your_private_key_here

# 区块浏览器 API Key（用于合约验证）
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## 特殊功能

1. **升级合约**: 使用代理合约模式实现合约升级，特别是 NFT 市场 V2 版本
2. **签名技术**: 支持 EIP-712、EIP-2612 Permit、Permit2 等签名标准
3. **权限控制**: 多签钱包、Ownable 合约等多种权限模型
4. **Gas 优化**: 访问列表、交易模拟等优化技术
5. **事件监听**: 实时监控代币和 ETH 转账事件

## 部署脚本说明

项目包含 36 个部署脚本，位于 `contracts/script/` 目录，每个合约都有对应的部署脚本：

**部署脚本命名规范**：`<ContractName>.s.sol`，脚本类名为 `<ContractName>Script`

**常用部署脚本示例**：
- `Counter.s.sol`: 基础计数器合约部署
- `BaseERC20.s.sol`: ERC-20 代币部署
- `MinimalERC721.s.sol`: ERC-721 NFT 部署
- `NFTMarketV2.s.sol`: NFT 市场（可升级版本）部署
- `TokenBank.s.sol`: 代币银行部署
- `ProposalMultiSigWallet.s.sol`: 提案型多签钱包部署
- `TransactionMultiSigWallet.s.sol`: 交易型多签钱包部署

**部署命令模板**：
```bash
cd contracts && forge script script/<ContractName>.s.sol:<ContractName>Script \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## 开发注意事项

- 智能合约工程位于 `contracts/` 子目录，**所有 forge 命令必须在 `contracts/` 目录下运行**
- 智能合约测试文件位于 `contracts/test/` 目录，使用 Foundry 的测试框架
- 智能合约部署脚本位于 `contracts/script/` 目录，使用 Foundry 的脚本功能
- 智能合约工程安装依赖**必须**使用 `--no-git` 标志，例如：`forge install --no-git https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable@v5.5.0`
- 前端组件使用 wagmi 和 viem 进行区块链交互
- 所有交易构建脚本使用 TypeScript 和 viem 库
- 升级合约必须遵循 OpenZeppelin 的初始化和升级安全模式
- **ABI 文件生成**：每次修改合约后，需要重新生成 ABI 文件并放到 `abis/` 目录供前端使用
- **本地测试**：使用 `anvil` 启动本地节点，然后部署合约进行测试
- **环境变量**：不要将 `.env` 文件提交到 git，私钥等敏感信息必须保密