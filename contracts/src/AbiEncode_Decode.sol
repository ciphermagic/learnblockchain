// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// 0x5FbDB2315678afecb367f032d93F642f64180aa3
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// forge create src/testAbiEncode_Decode.sol:AbiEncode --rpc-url local --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
// 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
contract AbiEncode {

    /**
      cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
        "forwardCall(address,bytes)" \
        0x5FbDB2315678afecb367f032d93F642f64180aa3 \
        0xa9059cbb00000000000000000000000000000000000000000000000000000000000012340000000000000000000000000000000000000000000000000000000000000064 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
     */
    function forwardCall(address _contract, bytes calldata data) external {
        (bool ok, bytes memory ret) = _contract.call(data);
        if (!ok) {
            // 把底层 revert 原因解码出来
            if (ret.length > 0) {
                assembly { revert(add(ret, 0x20), mload(ret)) }
            } else {
                revert("call failed (no revert reason)");
            }
        }
    }

    // cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "encodeWithSignature(address,uint256)(bytes)" 0x0000000000000000000000000000000000001234 100
    function encodeWithSignature(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // Typo is not checked - "transfer(address, uint)"
        return abi.encodeWithSignature("transfer(address,uint256)", to, amount);
    }

    // cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "encodeWithSelector(address,uint256)(bytes)" 0x0000000000000000000000000000000000001234 100
    function encodeWithSelector(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // Type is not checked - (IERC20.transfer.selector, true, amount)
        return abi.encodeWithSelector(IERC20.transfer.selector, to, amount);
    }

    // cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "encodeCall(address,uint256)(bytes)" 0x0000000000000000000000000000000000001234 100
    function encodeCall(address to, uint256 amount)
    external
    pure
    returns (bytes memory)
    {
        // Typo and type errors will not compile
        return abi.encodeCall(IERC20.transfer, (to, amount));
    }

    // cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 "encodeParameter(address,uint256)(bytes)" 0x0000000000000000000000000000000000001234 100
    function encodeParameter(address to, uint256 amount) public pure returns (bytes memory){
        return abi.encode(to, amount);
    }
}

contract AbiDecode {
    struct MyStruct {
        string name;
        uint256[2] nums;
    }

    function encode(
        uint256 x,
        address addr,
        uint256[] calldata arr,
        MyStruct calldata myStruct
    ) external pure returns (bytes memory) {
        return abi.encode(x, addr, arr, myStruct);
    }

    function decode(bytes calldata data)
    external
    pure
    returns (
        uint256 x,
        address addr,
        uint256[] memory arr,
        MyStruct memory myStruct
    )
    {
        // (uint x, address addr, uint[] memory arr, MyStruct myStruct) = ...
        (x, addr, arr, myStruct) =
        abi.decode(data, (uint256, address, uint256[], MyStruct));
    }
}