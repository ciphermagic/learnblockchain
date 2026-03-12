// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// forge script script/ERC721_Upgrade.s.sol:ERC721UpgradeScript --rpc-url <network> --broadcast
// forge inspect src/ERC721_Upgrade.sol:ERC721_Upgrade abi --json > ../abis/ERC721_Upgrade.json
import "./BaseScript.sol";
import {ERC721_Upgrade} from "../src/ERC721_Upgrade.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title ERC721_Upgrade 部署脚本
 * @notice 部署可升级的 ERC721 NFT 合约
 * @dev 使用 ERC1967 代理模式实现合约升级能力
 *
 * 部署流程：
 * 1. 部署 ERC721_Upgrade 实现合约
 * 2. 编码初始化数据（包含 NFT 名称和符号）
 * 3. 部署 ERC1967Proxy 代理合约
 * 4. 保存代理合约地址到 JSON 文件
 *
 * @custom:security 代理合约部署后，实现合约地址不应直接使用
 * @custom:upgrade 升级时需要调用代理合约的 upgradeTo 函数
 */
contract ERC721UpgradeScript is BaseScript {
    ERC721_Upgrade public erc721Upgrade;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 部署 ERC721_Upgrade 实现合约
        address impl = address(new ERC721_Upgrade());
        console.log("ERC721_Upgrade implementation deployed at:", impl);

        // 编码初始化函数调用数据，包含 NFT 名称和符号
        bytes memory initData = abi.encodeWithSelector(
            ERC721_Upgrade.initialize.selector,
            "TestNFT", // name
            "TNFT"     // symbol
        );

        // 部署 ERC1967 代理合约，传入实现合约地址和初始化数据
        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        erc721Upgrade = ERC721_Upgrade(address(proxy));
        console.log("ERC721_Upgrade proxy deployed at:", address(erc721Upgrade));
        saveContract("ERC721_Upgrade", address(erc721Upgrade));
    }
}