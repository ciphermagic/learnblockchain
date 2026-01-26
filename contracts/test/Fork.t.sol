// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {Owner} from "../src/Owner.sol";
import {BaseERC20} from "../src/BaseERC20.sol";

contract ForkTest is Test {
    Counter public counter;
    address public alice;
    address public bob;
    uint256 public sepoliaForkId;

    function setUp() public {
        uint forkBlock = 8219000;
        sepoliaForkId = vm.createSelectFork(vm.rpcUrl("sepolia"), forkBlock);
    }

    function test_Sepolia() public {

        vm.selectFork(sepoliaForkId);
        assertEq(vm.activeFork(), sepoliaForkId);

        BaseERC20 token = BaseERC20(0x21b4D1f6d42dc6083db848D42AA4b6895371E1e7);
        assertGe(token.balanceOf(0xe7a4159Be8c74c3BB38A45B31cF59889EF3F32b7), 1e18);
    }
}