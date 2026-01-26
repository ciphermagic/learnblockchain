// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Script.sol";

contract BaseScript is Script {
    uint256 internal deployerPrivateKey;
    address internal deployer;
    bool internal isPrivateKeySet;

    uint internal constant ANVIL = 31337;
    uint internal constant SEPOLIA = 11155111;

    constructor(string memory _privateKeyEnv) {
        if (block.chainid == ANVIL) {
            require(bytes(_privateKeyEnv).length != 0, "private key env must set by anvil");
            isPrivateKeySet = true;
            deployerPrivateKey = vm.envUint(_privateKeyEnv);
        } else {
            require(block.chainid == SEPOLIA, "only support sepolia");
        }
    }

    function saveContract(string memory name, address addr) public {
        string memory networkName = getChain(block.chainid).name;
        string memory key = string(abi.encodePacked(name, "_", networkName));
        string memory json = vm.serializeAddress(key, "address", addr);
        if (isPrivateKeySet) {
            json = vm.serializeAddress(key, "deployer", deployer);
        }
        string memory fileName = string.concat("deployments/", name, "_", networkName, ".json");
        vm.writeJson(json, fileName);
    }

    modifier broadcaster() {
        if (isPrivateKeySet) {
            vm.startBroadcast(deployerPrivateKey);
            deployer = vm.addr(deployerPrivateKey);
        } else {
            vm.startBroadcast();
        }
        _;
        vm.stopBroadcast();
    }
}
