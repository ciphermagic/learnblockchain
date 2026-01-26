pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import "./TokenBank.sol";

// TokenBankV2合约，支持直接通过transferWithCallback存入代币
contract TokenBankReceiver is TokenBank, IERC1363Receiver {
    // 扩展的ERC20代币合约地址
    ERC1363 public extendedToken;

    // 构造函数，设置扩展的ERC20代币合约地址
    constructor(address _tokenAddress) TokenBank(_tokenAddress) {
        extendedToken = ERC1363(_tokenAddress);
    }

    function onTransferReceived(
        address operator,     // 调用转账的人（通常是买家）
        address from,         // 付款人（买家）
        uint256 amount,       // 支付金额
        bytes calldata data   // 附加数据
    ) external override returns (bytes4) {
        require(msg.sender == operator, "NFTMarket: caller is not the operator");
        // 检查调用者是否为代币合约
        require(msg.sender == address(token), "TokenBankV2: caller is not the token contract");

        // 更新用户的存款记录
        deposits[from] += amount;

        // 触发存款事件
        emit Deposit(from, amount);

        return this.onTransferReceived.selector;
    }
}