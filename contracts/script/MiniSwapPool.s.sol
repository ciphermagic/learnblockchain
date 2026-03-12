// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// forge script script/MiniSwapPool.s.sol:MiniSwapPoolScript --rpc-url <network> --broadcast
// forge inspect src/MiniSwapPool.sol:MiniSwapPool abi --json > ../abis/MiniSwapPool.json
import "./BaseScript.sol";
import {MiniSwapPool} from "../src/MiniSwapPool.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title MiniSwapPool 部署脚本
 * @notice 部署简化版 Swap 池合约
 * @dev 需要配置两个代币地址和池子的名称/符号
 *
 * 部署流程：
 * 1. 配置 token0 和 token1 地址（交易对）
 * 2. 配置池子代币的名称和符号
 * 3. 部署 MiniSwapPool 合约
 * 4. 保存合约地址到 JSON 文件
 *
 * @custom:security 确保 token0 和 token1 地址有效且不相同
 */
contract MiniSwapPoolScript is BaseScript {
    MiniSwapPool public miniSwapPool;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 配置交易对代币地址（实际部署时需要替换为真实 ERC20 代币地址）
        address token0 = 0x0000000000000000000000000000000000000000;
        address token1 = 0x0000000000000000000000000000000000000000;

        // 配置池子代币的名称和符号
        string memory name = "MiniSwap Pool Token";
        string memory symbol = "MSP";

        // 部署 MiniSwapPool 合约
        miniSwapPool = new MiniSwapPool(token0, token1, name, symbol);
        console.log("MiniSwapPool deployed at:", address(miniSwapPool));
        saveContract("MiniSwapPool", address(miniSwapPool));
    }
}