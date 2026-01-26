// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
阅读代码  Vault.sol 及测试用例，在测试用例中 testExploit 函数添加一些代码，设法取出预先部署的 Vault 合约内的所有资金。
以便运行 forge test 可以通过所有测试。
可以在 Vault.t.sol 中添加代码，或加入新合约，但不要修改已有代码。
*/
contract VaultLogic {

    address public owner;
    bytes32 private password;

    constructor(bytes32 _password) {
        owner = msg.sender;
        password = _password;
    }

    function changeOwner(bytes32 _password, address newOwner) public {
        if (password == _password) {
            owner = newOwner;
        } else {
            revert("password error");
        }
    }
}

contract Vault {

    address public owner;
    VaultLogic logic;
    mapping(address => uint) deposites;
    bool public canWithdraw = false;

    constructor(address _logicAddress) {
        logic = VaultLogic(_logicAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(logic).delegatecall(msg.data);
        if (result) {
            this;
        }
    }

    receive() external payable {
    }

    function deposit() public payable {
        deposites[msg.sender] += msg.value;
    }

    function isSolve() external view returns (bool){
        if (address(this).balance == 0) {
            return true;
        }
        return false;
    }

    function openWithdraw() external {
        if (owner == msg.sender) {
            canWithdraw = true;
        } else {
            revert("not owner");
        }
    }

    function withdraw() public {
        if (canWithdraw && deposites[msg.sender] >= 0) {
            (bool result,) = msg.sender.call{value: deposites[msg.sender]}("");
            if (result) {
                deposites[msg.sender] = 0;
            }
        }
    }
}