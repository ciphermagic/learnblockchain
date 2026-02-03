// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/Vault.s.sol:VaultScript --rpc-url <network> --broadcast
// forge inspect src/Vault.sol:Vault abi --json > ../abis/Vault.json
import "./BaseScript.sol";
import {Vault, VaultLogic} from "../src/Vault.sol";
import {Script} from "forge-std/Script.sol";

contract VaultScript is BaseScript {
    Vault public vault;
    VaultLogic public vaultLogic;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        // 首先部署VaultLogic，使用默认密码
        bytes32 defaultPassword = keccak256("default_password");
        vaultLogic = new VaultLogic(defaultPassword);
        console.log("VaultLogic deployed at:", address(vaultLogic));

        // 然后部署Vault，传入VaultLogic的地址
        vault = new Vault(address(vaultLogic));
        console.log("Vault deployed at:", address(vault));

        saveContract("VaultLogic", address(vaultLogic));
        saveContract("Vault", address(vault));
    }
}