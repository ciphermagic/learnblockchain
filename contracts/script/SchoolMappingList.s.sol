// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forge script script/SchoolMappingList.s.sol:SchoolMappingListScript --rpc-url <network> --broadcast
// forge inspect src/SchoolMappingList.sol:SchoolMappingList abi --json > ../abis/SchoolMappingList.json
import "./BaseScript.sol";
import {SchoolMappingList} from "../src/SchoolMappingList.sol";
import {Script} from "forge-std/Script.sol";

contract SchoolMappingListScript is BaseScript {
    SchoolMappingList public schoolMappingList;

    constructor() BaseScript("LOCAL1_PRIVATE_KEY") {}

    function run() public broadcaster {
        schoolMappingList = new SchoolMappingList();
        console.log("SchoolMappingList deployed at:", address(schoolMappingList));
        saveContract("SchoolMappingList", address(schoolMappingList));
    }
}