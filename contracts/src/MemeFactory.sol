// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title MemeToken
 * @dev 基于 ERC20Upgradeable 的 Meme 代币实现，支持通过工厂合约铸造代币
 *      采用最小代理模式（EIP-1167）部署，降低 Gas 成本
 *      支持刻字（Inscription）模式的用户，每次铸造固定数量的代币
 */
contract MemeToken is Initializable, ERC20Upgradeable {
    /// @dev 代币创建者地址，部署后不可修改
    address public memeCreator;
    /// @dev 工厂合约地址，用于权限控制，只有工厂可以铸造代币
    address public factory;
    /// @dev 代币总供应量（固定不可增发）
    uint256 public totalSupply_;
    /// @dev 每次铸造的代币数量（刻字模式下固定值）
    uint256 public perMint;
    /// @dev 每个代币的价格（以 Wei 为单位），用于计算购买费用
    uint256 public price;
    /// @dev 已铸造的代币总量
    uint256 public mintedAmount;

    /**
     * @dev 初始化 Meme 代币
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _totalSupply 总供应量
     * @param _perMint 每次铸造的数量
     * @param _price 每个代币的价格（wei）
     * @param _creator 创建者地址
     * @notice 使用 initializer 修饰符确保只能初始化一次，防止重入攻击
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external initializer {
        // 防止重复初始化（重入防护）
        require(memeCreator == address(0), "Already initialized");
        require(_totalSupply > 0, "Total supply must be greater than 0");
        require(_perMint > 0, "Per mint must be greater than 0");
        require(_perMint <= _totalSupply, "Per mint must be less than or equal to total supply");

        __ERC20_init(_name, _symbol);
        totalSupply_ = _totalSupply;
        perMint = _perMint;
        price = _price;
        memeCreator = _creator;
        factory = msg.sender;  // 设置工厂合约地址为调用初始化函数的地址
        mintedAmount = 0;
    }

    /**
     * @dev 铸造新的代币
     * @param to 接收者地址
     * @return 是否成功
     * @notice 只有工厂合约可以调用此函数进行铸造，确保铸造权限受控
     * @dev 铸造前检查是否超过总供应量，防止超额铸造
     */
    function mint(address to) external returns (bool) {
        // 权限控制：只有工厂合约可以铸造
        require(msg.sender == factory, "Only factory can mint");  // 使用存储的工厂地址
        // 铸造量检查：确保不会超过总供应量
        require(mintedAmount + perMint <= totalSupply_, "Exceeds total supply");

        mintedAmount += perMint;
        _mint(to, perMint);
        return true;
    }
}

/**
 * @title MemeFactory
 * @dev Meme 代币工厂合约，使用最小代理模式（EIP-1167）部署代币
 *      采用代理模式可以大幅降低代币部署的 Gas 成本（每次部署只需约 10 万 Gas）
 *      支持刻字模式（Inscription）：用户支付 ETH 后铸造固定数量的代币
 *      项目方收取 1% 的费用作为收益
 */
contract MemeFactory is Ownable {
    using Clones for address;

    /// @dev 项目方地址，用于接收费用
    address public projectOwner;
    /// @dev 项目方费用比例（1%），费用从用户支付中抽取
    uint256 public constant PROJECT_FEE_PERCENT = 1;
    /// @dev 基础代币实现合约地址（模板合约）
    address public implementation;
    /// @dev 记录已通过本工厂部署的代币地址，防止伪造
    mapping(address => bool) public deployedTokens;

    /// @dev 当新代币部署时触发
    event MemeDeployed(address indexed tokenAddress, address indexed creator, string symbol, uint256 totalSupply, uint256 perMint, uint256 price);
    /// @dev 当用户购买/铸造代币时触发
    event MemeMinted(address indexed tokenAddress, address indexed buyer, uint256 amount, uint256 paid);

    /**
     * @dev 构造函数
     * @param _projectOwner 项目方地址，用于接收费用
     */
    constructor(address _projectOwner) Ownable(msg.sender) {
        require(_projectOwner != address(0), "Invalid project owner");
        projectOwner = _projectOwner;

        // 部署基础代币实现（模板合约）
        implementation = address(new MemeToken());
    }

    /**
     * @dev 部署新的 Meme 代币（刻字模式）
     * @param name 代币名称
     * @param symbol 代币符号
     * @param totalSupply 总供应量（固定）
     * @param perMint 每次铸造的数量
     * @param price 每个代币的价格（wei）
     * @return tokenAddr 新部署的代币地址（代理合约）
     * @notice 使用 Clones 库创建最小代理，只需部署一个模板合约
     */
    function deployInscription(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address tokenAddr) {
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint must be less than or equal to total supply");

        // 使用 Clones 库创建最小代理（EIP-1167）
        tokenAddr = implementation.clone();

        // 初始化代币参数
        MemeToken(tokenAddr).initialize(name, symbol, totalSupply, perMint, price, msg.sender);

        // 记录已部署的代币，防止伪造
        deployedTokens[tokenAddr] = true;

        emit MemeDeployed(tokenAddr, msg.sender, symbol, totalSupply, perMint, price);

        return tokenAddr;
    }

    /**
     * @dev 铸造 Meme 代币（购买刻字）
     * @param tokenAddr 代币地址
     * @notice 用户发送 ETH 购买代币，费用分配给项目方和创建者
     *         如果支付超过所需金额，多余的 ETH 会被退还
     */
    function mintInscription(address tokenAddr) external payable {
        // 验证代币是否由本工厂部署
        require(deployedTokens[tokenAddr], "Token not deployed by this factory");

        MemeToken token = MemeToken(tokenAddr);

        // 检查是否超过总供应量
        require(token.mintedAmount() + token.perMint() <= token.totalSupply_(), "Exceeds total supply");

        // 计算所需支付金额（price * perMint / 1e18）
        uint256 requiredAmount = token.price() * token.perMint() / 1e18;
        require(msg.value >= requiredAmount, "Insufficient payment");

        // 计算费用分配：项目方 1%，创建者 99%
        uint256 projectFee = (requiredAmount * PROJECT_FEE_PERCENT) / 100;
        uint256 creatorFee = requiredAmount - projectFee;

        // 分配费用（使用 call 而不是 transfer，避免 gas 限制问题）
        (bool projectSuccess,) = payable(projectOwner).call{value: projectFee}("");
        require(projectSuccess, "Project fee transfer failed");

        (bool creatorSuccess,) = payable(token.memeCreator()).call{value: creatorFee}("");
        require(creatorSuccess, "Creator fee transfer failed");

        // 铸造代币给买家
        token.mint(msg.sender);

        // 退还多余的 ETH
        if (msg.value > requiredAmount) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - requiredAmount}("");
            require(refundSuccess, "Refund failed");
        }

        emit MemeMinted(tokenAddr, msg.sender, token.perMint(), requiredAmount);
    }

    /**
     * @dev 更新项目方地址
     * @param _newProjectOwner 新的项目方地址
     * @notice 只有合约所有者可以调用
     */
    function updateProjectOwner(address _newProjectOwner) external onlyOwner {
        require(_newProjectOwner != address(0), "Invalid project owner");
        projectOwner = _newProjectOwner;
    }
}