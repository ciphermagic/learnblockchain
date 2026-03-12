// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseScript.sol";
import "../src/NFTMarketV2.sol";
import "../src/MyERC1363Token.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title NFTMarketV2 部署脚本
 * @notice 部署可升级的 NFT 市场合约（V2 版本）
 * @dev 使用 ERC1967 代理模式实现合约升级能力
 *
 * 部署流程：
 * 1. 部署 MyERC1363Token 作为支付代币
 * 2. 部署 NFTMarketV2 实现合约
 * 3. 编码初始化数据（包含支付代币地址）
 * 4. 部署 ERC1967Proxy 代理合约
 * 5. 保存代理合约地址到 JSON 文件
 *
 * @custom:security 代理合约部署后，实现合约地址不应直接使用
 * @custom:upgrade 升级时需要调用代理合约的 upgradeTo 函数
 */
contract NFTMarketV2Script is BaseScript {
    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() external broadcaster {
        // 部署 MyERC1363Token 作为支付代币
        MyERC1363Token paymentToken = new MyERC1363Token("NFT Payment Token", "NPT");
        console.log("MyERC1363Token deployed at:", address(paymentToken));
        saveContract("MyERC1363Token", address(paymentToken));

        // 部署 NFTMarketV2 实现合约
        address impl = address(new NFTMarketV2());
        console.log("NFTMarketV2 implementation deployed at:", impl);

        // 编码初始化函数调用数据，包含支付代币地址参数
        bytes memory initData = abi.encodeWithSelector(
            NFTMarketV2.initialize.selector,
            address(paymentToken)
        );

        // 部署 ERC1967 代理合约，传入实现合约地址和初始化数据
        ERC1967Proxy proxy = new ERC1967Proxy(impl, initData);
        NFTMarketV2 nftMarket = NFTMarketV2(address(proxy));
        console.log("NFTMarketV2 proxy deployed at:", address(nftMarket));
        saveContract("NFTMarketV2", address(nftMarket));
    }
}