# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个全栈 Web3 学习与实战项目，名为 "Learn Blockchain"，覆盖智能合约开发、前端 DApp 交互、链上操作脚本三大核心领域。项目使用 Next.js 作为前端框架，Foundry 作为智能合约开发工具集，以及 Viem 和 Wagmi 作为 Web3 交互库。

## 技术栈

- **智能合约**: Solidity 0.8.20+, Foundry, OpenZeppelin Contracts
- **前端**: Next.js 14+, TypeScript, viem, wagmi, Tailwind CSS
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

# 运行单个测试
cd contracts && forge test --match-test TestFunctionName

# 部署到本地节点
cd contracts && forge script script/Counter.s.sol:CounterScript --fork-url http://localhost:8545 --broadcast

# 查看 gas 使用情况
cd contracts && forge test --gas-report
```

### 前端开发
```bash
# 安装依赖
pnpm install

# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build
```

### 脚本执行
```bash
# 运行演示脚本
pnpm tsx scripts/index.ts

# 运行特定脚本
pnpm tsx scripts/scanERC20Transfers.ts
```

## 重要配置文件

- `contracts/foundry.toml`: Foundry 配置，包含优化设置、RPC 端点
- `contracts/remappings.txt`: Solidity 导入路径映射
- `package.json`: 前端依赖和脚本配置
- `.env`: 环境变量配置（RPC URLs、API keys）

## 特殊功能

1. **升级合约**: 使用代理合约模式实现合约升级，特别是 NFT 市场 V2 版本
2. **签名技术**: 支持 EIP-712、EIP-2612 Permit、Permit2 等签名标准
3. **权限控制**: 多签钱包、Ownable 合约等多种权限模型
4. **Gas 优化**: 访问列表、交易模拟等优化技术
5. **事件监听**: 实时监控代币和 ETH 转账事件

## 开发注意事项

- 智能合约工程位于 `contracts/` 子目录，所有 forge 命令必须运行在 `contracts/` 目录下
- 智能合约测试文件位于 `contracts/test/` 目录，使用 Foundry 的测试框架
- 智能合约部署脚本位于 `contracts/script/` 目录，使用 Foundry 的脚本功能
- 智能合约工程安装依赖**必须**使用`--no-git`，例如：`forge install --no-git https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable@v5.5.0`
- 前端组件使用 wagmi 和 viem 进行区块链交互
- 所有交易构建脚本使用 TypeScript 和 viem 库
- 升级合约必须遵循 OpenZeppelin 的初始化和升级安全模式