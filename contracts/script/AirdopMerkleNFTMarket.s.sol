// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/AirdopMerkleNFTMarket.s.sol:AirdopMerkleNFTMarketScript --rpc-url <network> --broadcast
// forge inspect src/AirdopMerkleNFTMarket.sol:AirdopMerkleNFTMarket abi --json > ../abis/AirdopMerkleNFTMarket.json
import "./BaseScript.sol";
import {AirdopMerkleNFTMarket} from "../src/AirdopMerkleNFTMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

contract AirdopMerkleNFTMarketScript is BaseScript {
    AirdopMerkleNFTMarket public airdropMerkleNFTMarket;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 使用占位符地址作为支付代币和Merkle树根
        address paymentTokenAddress = 0x0000000000000000000000000000000000000000;
        bytes32 merkleRoot = bytes32(0);

        airdropMerkleNFTMarket = new AirdopMerkleNFTMarket(paymentTokenAddress, merkleRoot);
        console.log("AirdopMerkleNFTMarket deployed at:", address(airdropMerkleNFTMarket));
        saveContract("AirdopMerkleNFTMarket", address(airdropMerkleNFTMarket));
    }
}