// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title MinimalERC721
 * @notice 极简版 ERC721 NFT 合约，用于测试和演示
 * @dev 继承自 OpenZeppelin 的 ERC721 和 ERC721Enumerable
 *
 * 核心功能：
 * - 支持 ERC721 标准的 NFT 铸造、转移、授权
 * - 支持 ERC721Enumerable 扩展，可枚举所有 token 和用户持有的 token
 * - 提供公开的 mint 函数，任何人都可以铸造 NFT（无权限控制）
 * - 自动递增的 tokenId，从 0 开始
 *
 * 使用场景：
 * - NFT 市场测试：作为测试用的 NFT 合约
 * - 学习演示：展示 ERC721 的基本实现
 * - 快速原型：需要简单 NFT 功能的场景
 *
 * 安全注意：
 * - 无权限控制：任何人都可以铸造 NFT
 * - 无铸造上限：可以无限铸造
 * - 生产环境需要添加权限控制（如 Ownable）和铸造上限
 */
contract MinimalERC721 is ERC721, ERC721Enumerable {
    /// @notice tokenId 计数器，用于生成唯一的 token ID
    /// @dev 从 0 开始递增，每次 mint 后自增 1
    uint256 private _tokenIdCounter;

    /**
     * @notice 构造函数，初始化 NFT 合约
     * @param name NFT 集合的名称（如 "My NFT Collection"）
     * @param symbol NFT 集合的符号（如 "MNFT"）
     * @dev tokenId 计数器默认从 0 开始
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    }

    /**
     * @notice 铸造新的 NFT
     * @param to NFT 接收者地址
     * @return tokenId 新铸造的 NFT 的 token ID
     *
     * @dev 执行流程：
     * 1. 获取当前 tokenId（从 0 开始）
     * 2. 计数器自增，为下次铸造准备
     * 3. 调用 ERC721 的 _mint 函数铸造 NFT
     * 4. 返回铸造的 tokenId
     *
     * 安全注意：
     * - 无权限控制：任何人都可以调用
     * - 无铸造上限：可以无限铸造
     * - 生产环境建议添加 onlyOwner 修饰器
     * - 建议添加最大供应量限制
     */
    function mint(address to) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }

    /**
     * @notice 内部函数：更新 NFT 的所有权状态
     * @param to 新的所有者地址（address(0) 表示销毁）
     * @param tokenId 要更新的 token ID
     * @param auth 授权执行此操作的地址
     * @return 返回之前的所有者地址
     *
     * @dev 多重继承冲突解决：
     * - ERC721 和 ERC721Enumerable 都实现了 _update 函数
     * - 必须显式 override 并调用 super._update
     * - super._update 会按照继承顺序调用所有父合约的实现
     * - ERC721Enumerable 会在此函数中更新枚举数据结构
     *
     * 调用时机：
     * - mint：to != address(0), auth = address(0)
     * - transfer：to != address(0), auth = msg.sender
     * - burn：to = address(0), auth = owner
     */
    function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721, ERC721Enumerable)
    returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @notice 内部函数：增加账户的 NFT 余额
     * @param account 要增加余额的账户地址
     * @param value 要增加的数量
     *
     * @dev 多重继承冲突解决：
     * - ERC721 和 ERC721Enumerable 都实现了 _increaseBalance 函数
     * - 必须显式 override 并调用 super._increaseBalance
     * - ERC721Enumerable 会在此函数中更新枚举数据结构
     *
     * 调用时机：
     * - mint 时增加接收者余额
     * - transfer 时增加接收者余额（同时减少发送者余额）
     */
    function _increaseBalance(address account, uint128 value)
    internal
    override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    /**
     * @notice 检查合约是否支持指定的接口
     * @param interfaceId 接口 ID（ERC165 标准）
     * @return 如果支持该接口返回 true，否则返回 false
     *
     * @dev 多重继承冲突解决：
     * - ERC721 和 ERC721Enumerable 都实现了 supportsInterface 函数
     * - 必须显式 override 并调用 super.supportsInterface
     * - 支持的接口包括：
     *   - ERC165: 0x01ffc9a7
     *   - ERC721: 0x80ac58cd
     *   - ERC721Metadata: 0x5b5e139f
     *   - ERC721Enumerable: 0x780e9d63
     */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}