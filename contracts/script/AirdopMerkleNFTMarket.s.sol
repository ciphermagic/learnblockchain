// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/AirdopMerkleNFTMarket.s.sol:AirdopMerkleNFTMarketScript --rpc-url <network> --broadcast
// forge inspect src/AirdopMerkleNFTMarket.sol:AirdopMerkleNFTMarket abi --json > ../abis/AirdopMerkleNFTMarket.json
import "./BaseScript.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

/**
 * @title AirdopMerkleNFTMarket 部署脚本
 * @notice 部署基于 Merkle Tree 的 NFT 空投市场合约
 * @dev 需要配置支付代币地址和 Merkle Tree 根哈希
 *
 * 部署流程：
 * 1. 配置支付代币地址（用于购买 NFT）
 * 2. 配置 Merkle Tree 根哈希（用于验证空投白名单）
 * 3. 部署 AirdopMerkleNFTMarket 合约
 * 4. 保存合约地址到 JSON 文件
 *
 * @custom:security 确保 Merkle Root 正确生成，避免白名单验证失败
 */
contract AirdopMerkleNFTMarketScript is BaseScript {
    AirdopMerkleNFTMarket public airdropMerkleNFTMarket;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 配置支付代币地址（实际部署时需要替换为真实 ERC20 代币地址）
        address paymentTokenAddress = 0x0000000000000000000000000000000000000000;

        // 配置 Merkle Tree 根哈希（实际部署时需要根据白名单生成）
        bytes32 merkleRoot = bytes32(0);

        // 部署 AirdopMerkleNFTMarket 合约
        airdropMerkleNFTMarket = new AirdopMerkleNFTMarket(paymentTokenAddress, merkleRoot);
        console.log("AirdopMerkleNFTMarket deployed at:", address(airdropMerkleNFTMarket));
        saveContract("AirdopMerkleNFTMarket", address(airdropMerkleNFTMarket));
    }
}