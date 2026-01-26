// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {AbiEncode, AbiDecode} from "../src/AbiEncode_Decode.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AbiEncodeDecodeTest is Test {
    AbiEncode public abiEncode;
    AbiDecode public abiDecode;

    function setUp() public {
        abiEncode = new AbiEncode();
        abiDecode = new AbiDecode();
    }

    function test_EncodeWithSignature() public {
        address to = address(0x123);
        uint256 amount = 100;

        bytes memory encoded = abiEncode.encodeWithSignature(to, amount);
        console.logBytes( encoded);

        // Verify the encoding worked by checking the function selector (first 4 bytes)
        bytes4 selector = bytes4(keccak256("transfer(address,uint256)"));
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
    }

    function test_EncodeWithSelector() public {
        address to = address(0x123);
        uint256 amount = 100;

        bytes memory encoded = abiEncode.encodeWithSelector(to, amount);
        console.logBytes( encoded);

        // Verify the encoding worked by checking the function selector (first 4 bytes)
        bytes4 selector = IERC20.transfer.selector;
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
        console.log("encodeWithSelector test passed");
    }

    function test_EncodeCall() public {
        address to = address(0x123);
        uint256 amount = 100;

        bytes memory encoded = abiEncode.encodeCall(to, amount);
        console.logBytes( encoded);
        // Verify the encoding worked by checking the function selector (first 4 bytes)
        bytes4 selector = IERC20.transfer.selector;
        bytes4 encodedSelector = bytes4(encoded);

        assertEq(selector, encodedSelector, "Function selector mismatch");
        console.log("encodeCall test passed");
    }

    function test_EncodeParameter() public {
        address to = address(0x123);
        uint256 amount = 100;

        bytes memory encoded = abiEncode.encodeParameter(to, amount);
        console.logBytes( encoded);
        // Decode the parameters to verify they were encoded correctly
        (address decodedTo, uint256 decodedAmount) = abi.decode(encoded, (address, uint256));

        assertEq(to, decodedTo, "Address mismatch");
        assertEq(amount, decodedAmount, "Amount mismatch");
        console.log("encodeParameter test passed");
    }

    function test_EncodeAndDecode() public {
        // Prepare test data
        uint256 x = 42;
        address addr = address(0x456);
        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;

        AbiDecode.MyStruct memory myStruct = AbiDecode.MyStruct({
            name: "test",
            nums: [uint256(10), uint256(20)]
        });

        // Encode the data
        bytes memory encoded = abiDecode.encode(x, addr, arr, myStruct);

        // Decode the data
        (uint256 decodedX, address decodedAddr, uint256[] memory decodedArr, AbiDecode.MyStruct memory decodedStruct) =
            abiDecode.decode(encoded);

        // Verify the decoded data matches the original
        assertEq(x, decodedX, "Uint256 mismatch");
        assertEq(addr, decodedAddr, "Address mismatch");

        assertEq(arr.length, decodedArr.length, "Array length mismatch");
        for (uint i = 0; i < arr.length; i++) {
            assertEq(arr[i], decodedArr[i], "Array element mismatch");
        }

        assertEq(myStruct.name, decodedStruct.name, "Struct name mismatch");
        assertEq(myStruct.nums[0], decodedStruct.nums[0], "Struct nums[0] mismatch");
        assertEq(myStruct.nums[1], decodedStruct.nums[1], "Struct nums[1] mismatch");

        console.log("encode and decode test passed");
    }

    function testFuzz_EncodeParameter(address to, uint256 amount) public {
        vm.assume(to != address(0));

        bytes memory encoded = abiEncode.encodeParameter(to, amount);

        // Decode the parameters to verify they were encoded correctly
        (address decodedTo, uint256 decodedAmount) = abi.decode(encoded, (address, uint256));

        assertEq(to, decodedTo, "Address mismatch");
        assertEq(amount, decodedAmount, "Amount mismatch");
    }
}