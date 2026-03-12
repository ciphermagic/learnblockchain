// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/ERC721_Upgrade_V2.s.sol:ERC721UpgradeV2Script --rpc-url <network> --broadcast
// forge inspect src/ERC721_Upgrade_V2.sol:ERC721_Upgrade_V2 abi --json > ../abis/ERC721_Upgrade_V2.json
import "./BaseScript.sol";
import {ERC721_Upgrade_V2} from "../src/ERC721_Upgrade_V2.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title ERC721_Upgrade_V2 部署脚本
 * @notice 部署 ERC721 升级合约的新实现版本（V2）
 * @dev 这是升级合约的新实现，用于替换现有代理合约指向的实现
 *
 * 部署流程：
 * 1. 部署 ERC721_Upgrade_V2 新实现合约
 * 2. 保存新实现合约地址到 JSON 文件
 * 3. 需要手动调用代理合约的 upgradeTo 函数完成升级
 *
 * @custom:security 部署后不要直接使用此地址，需要通过代理合约升级
 * @custom:upgrade 使用此地址调用现有代理合约的 upgradeTo(address) 函数
 */
contract ERC721UpgradeV2Script is BaseScript {
    ERC721_Upgrade_V2 public erc721UpgradeV2;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 部署 ERC721_Upgrade_V2 新实现合约（用于升级现有代理）
        erc721UpgradeV2 = new ERC721_Upgrade_V2();
        console.log("ERC721_Upgrade_V2 implementation deployed at:", address(erc721UpgradeV2));
        saveContract("ERC721_Upgrade_V2", address(erc721UpgradeV2));
    }
}