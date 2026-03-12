// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ERC721_Upgrade
 * @notice 可升级的ERC721 NFT合约（UUPS代理模式）
 * @dev 核心特性：
 *      1. UUPS代理模式：升级逻辑在实现合约中，节省gas
 *      2. 初始化器模式：使用initialize()替代constructor
 *      3. 权限控制：只有owner可以铸造NFT和升级合约
 *
 *      UUPS代理模式说明：
 *      - 代理合约：存储数据，delegatecall调用实现合约
 *      - 实现合约：包含业务逻辑和升级逻辑
 *      - 升级流程：owner调用upgradeTo()，更新代理合约指向的实现地址
 *
 *      继承顺序（从左到右）：
 *      1. Initializable：提供初始化器修饰符和防重入初始化
 *      2. ERC721Upgradeable：可升级版本的ERC721标准实现
 *      3. OwnableUpgradeable：可升级版本的所有权管理
 *      4. UUPSUpgradeable：UUPS代理模式的升级逻辑
 *
 *      安全机制：
 *      - _disableInitializers()：防止实现合约被直接初始化
 *      - initializer修饰符：确保initialize()只能调用一次
 *      - onlyOwner：只有owner可以铸造和升级
 *      - _authorizeUpgrade()：升级前的权限检查
 *
 *      存储布局：
 *      - 使用OpenZeppelin的存储槽机制，避免存储冲突
 *      - 升级时必须保持存储布局兼容性
 */
contract ERC721_Upgrade is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /**
     * @notice 构造函数，禁用实现合约的初始化
     * @dev 使用@custom:oz-upgrades-unsafe-allow constructor注解
     *      告诉OpenZeppelin升级插件这是安全的
     *
     *      为什么要禁用初始化：
     *      - 实现合约不应该被直接使用，只能通过代理调用
     *      - 防止攻击者直接初始化实现合约并获取控制权
     *      - _disableInitializers()会将initialized标志设为最大值
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化函数，替代构造函数
     * @param name NFT集合名称
     * @param symbol NFT集合符号
     * @dev 执行流程：
     *      1. initializer修饰符确保只能调用一次
     *      2. 初始化ERC721（名称和符号）
     *      3. 初始化Ownable（设置msg.sender为owner）
     *
     *      注意事项：
     *      - 必须在部署代理后立即调用
     *      - 只能调用一次，再次调用会revert
     *      - 不初始化UUPSUpgradeable（它没有初始化函数）
     */
    function initialize(string memory name, string memory symbol) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(msg.sender);
    }

    /**
     * @notice 铸造NFT
     * @param to 接收者地址
     * @param tokenId NFT的ID
     * @dev 权限控制：只有owner可以调用
     *      使用场景：管理员为用户铸造NFT
     */
    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }

    /**
     * @notice 升级授权检查
     * @param newImplementation 新实现合约地址
     * @dev UU求：
     *      - 必须重写此函数
     *      - 在升级前进行权限检查
     *      - 只有owner可以升级合约
     *
     *      升级流程：
     *      1. owner调用upgradeTo(newImplementation)
     *      2. UUPSUpgradeable调用_authorizeUpgrade()检查权限
     *      3. 权限通过后，更新代理合约的实现地址
     *      4. 后续调用将delegatecall到新实现合约
     *
     *      安全考虑：
     *      - 新实现合约必须也继承UUPSUpgradeable
     *      - 否则升级后将无法再次升级（合约被锁死）
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}