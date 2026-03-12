// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// forge script script/MemeFactoryV2.s.sol:MemeFactoryV2Script --rpc-url <network> --broadcast
// forge inspect src/MemeFactoryV2.sol:MemeFactoryV2 abi --json > ../abis/MemeFactoryV2.json
import "./BaseScript.sol";
import {MemeFactoryV2} from "../src/MemeFactoryV2.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title MemeFactoryV2 部署脚本
 * @notice 部署 Meme 代币工厂合约（V2 版本）
 * @dev 需要配置项目所有者地址和 Uniswap V2 Router 地址
 *
 * 部署流程：
 * 1. 配置项目所有者地址（接收手续费）
 * 2. 配置 Uniswap V2 Router 地址（用于创建流动性池）
 * 3. 部署 MemeFactoryV2 合约
 * 4. 保存合约地址到 JSON 文件
 *
 * @custom:security 确保 projectOwner 和 uniswapRouter 地址有效
 */
contract MemeFactoryV2Script is BaseScript {
    MemeFactoryV2 public memeFactoryV2;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 配置项目所有者地址（实际部署时需要替换为真实地址）
        address projectOwner = 0x0000000000000000000000000000000000000000;

        // 配置 Uniswap V2 Router 地址（实际部署时需要替换为对应网络的 Router 地址）
        address uniswapRouter = 0x0000000000000000000000000000000000000000;

        // 部署 MemeFactoryV2 合约
        memeFactoryV2 = new MemeFactoryV2(projectOwner, uniswapRouter);
        console.log("MemeFactoryV2 deployed at:", address(memeFactoryV2));
        saveContract("MemeFactoryV2", address(memeFactoryV2));
    }
}