// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1363.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title NFTMarketV1
 * @notice NFT 市场合约 V1 版本，支持 NFT 上架、购买、取消上架
 * @dev 可升级合约，使用 UUPS 代理模式
 *
 * 核心功能：
 * - NFT 上架：卖家可以将 NFT 上架到市场，设置价格
 * - NFT 购买：买家可以使用 ERC20 代币购买上架的 NFT
 * - 取消上架：卖家可以取消自己的上架
 * - 支持两种购买方式：
 *   1. 普通购买：买家调用 buyNFT，需要先授权代币
 *   2. ERC1363 购买：买家调用 transferAndCall，一步完成支付和购买
 *
 * 技术特性：
 * - 可升级：使用 UUPS 代理模式，支持合约逻辑升级
 * - 权限控制：只有 owner 可以升级合约
 * - ERC1363 集成：支持代币的 transferAndCall 功能
 * - 事件记录：完整的事件日志，方便前端监听
 *
 * 安全考虑：
 * - 上架时验证 NFT 所有权和授权
 * - 购买时验证上架状态和代币余额
 * - 使用 storage 引用避免重复读取
 * - 先标记状态再执行转账（防重入）
 * - 验证代币转账结果
 *
 * 升级模式：
 * - 使用 UUPS 代理模式（逻辑合约自己控制升级）
 * - 构造函数禁用初始化器（防止逻辑合约被初始化）
 * - 使用 initialize 函数初始化代理合约
 * - 只有 owner 可以授权升级
 */
contract NFTMarketV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC1363Receiver {
    /// @notice 支付代币合约（ERC1363 标准）
    /// @dev 买家使用此代币购买 NFT，卖家收到此代币
    IERC1363 public paymentToken;

    /**
     * @notice NFT 上架信息结构体
     * @dev 存储每个上架 NFT 的完整信息
     */
    struct Listing {
        address seller;      // 卖家地址（NFT 的原所有者）
        address nftContract; // NFT 合约地址
        uint256 tokenId;     // NFT 的 tokenId
        uint256 price;       // 价格（以 paymentToken 为单位）
        bool isActive;       // 是否处于活跃状态（false 表示已售出或已取消）
    }

    /// @notice 所有上架的 NFT，使用 listingId 作为唯一标识
    /// @dev listingId 从 0 开始递增，永不重复
    mapping(uint256 => Listing) public listings;

    /// @notice 下一个可用的 listingId
    /// @dev 每次上架时使用当前值，然后自增
    uint256 public nextListingId;

    /// @notice NFT 上架事件
    /// @param listingId 上架 ID
    /// @param seller 卖家地址
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT 的 tokenId
    /// @param price 价格
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);

    /// @notice NFT 售出事件
    /// @param listingId 上架 ID
    /// @param buyer 买家地址
    /// @param seller 卖家地址
    /// @param nftContract NFT 合约地址
    /// @param tokenId NFT 的 tokenId
    /// @param price 成交价格
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    /// @notice NFT 上架取消事件
    /// @param listingId 上架 ID
    event NFTListingCancelled(uint256 indexed listingId);

    /**
     * @notice 构造函数
     * @dev UUPS 代理模式要求：
     * - 禁用逻辑合约的初始化器，防止逻辑合约被直接初始化
     * - 实际初始化通过代理合约调用 initialize 函数完成
     * - @custom:oz-upgrades-unsafe-allow constructor 标记告诉 OpenZeppelin 升级插件这是安全的
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化函数（代替构造函数）
     * @param _paymentTokenAddress 支付代币合约地址（必须支持 ERC1363）
     *
     * @dev 初始化流程：
     * 1. 验证支付代币地址不为零地址
     * 2. 设置支付代币合约
     * 3. 初始化 Ownable（设置 msg.sender 为 owner）
     *
     * 安全注意：
     * - initializer 修饰器确保只能调用一次
     * - 必须在部署代理合约后立即调用
     * - 支付代币必须支持 ERC1363 标准
     */
    function initialize(address _paymentTokenAddress) public initializer {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        paymentToken = IERC1363(_paymentTokenAddress);

        __Ownable_init(msg.sender);
    }

    /**
     * @notice 授权升级函数
     * @param newImplementation 新的逻辑合约地址
     *
     * @dev UUPS 升级模式：
     * - 逻辑合约自己控制升级权限
     * - 只有 owner 可以升级合约
     * - 升级时会验证新合约是否兼容
     * - 升级后代理合约的存储保持不变
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice 上架 NFT 到市场
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT 的 tokenId
     * @param _price 价格（以 paymentToken 为单位）
     * @return listingId 上架 ID
     *
     * @dev 执行流程：
     * 1. 验证价格大于 0
     * 2. 验证 NFT 合约地址不为零地址
     * 3. 验证调用者是 NFT 所有者或已获得授权
     * 4. 创建上架信息（seller 为实际所有者，不是调用者）
     * 5. 递增 listingId 计数器
     * 6. 触发上架事件
     *
     * 权限验证：
     * - 调用者必须是 NFT 所有者，或
     * - 调用者获得了所有者的全局授权（isApprovedForAll），或
     * - 调用者获得了该 NFT 的单独授权（getApproved）
     *
     * 安全注意：
     * - 上架时不转移 NFT，NFT 仍在卖家手中
     * - 购买时才转移 NFT，需要卖家提前授权市场合约
     * - seller 记录的是实际所有者，不是调用者（支持代理上架）
     * - 同一个 NFT 可以多次上架（不同的 listingId）
     */
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        // 检查价格是否大于0
        require(_price > 0, "NFTMarket: price must be greater than zero");

        // 检查NFT合约地址是否有效
        require(_nftContract != address(0), "NFTMarket: NFT contract address cannot be zero");

        // 检查调用者是否为NFT的所有者或已获得授权
        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender ||
            nftContract.isApprovedForAll(owner, msg.sender) ||
            nftContract.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
        );

        // 创建新的上架信息
        uint256 listingId = nextListingId;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        // 增加listingId计数器
        nextListingId++;

        // 触发NFT上架事件
        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);

        return listingId;
    }

    /**
     * @notice 取消上架 NFT
     * @param _listingId 上架 ID
     *
     * @dev 执行流程：
     * 1. 验证上架信息存在且处于活跃状态
     * 2. 验证调用者是卖家
     * 3. 将上架标记为非活跃
     * 4. 触发取消事件
     *
     * 权限控制：
     * - 只有卖家可以取消自己的上架
     * - 即使 NFT 已转移给他人，原卖家仍可取消上架
     *
     * 安全注意：
     * - 使用 storage 引用避免重复读取
     * - 标记为非活跃而不是删除，保留历史记录
     * - 取消后无法恢复，需要重新上架
     */
    function cancelListing(uint256 _listingId) external {
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");

        // 检查调用者是否为卖家
        require(listing.seller == msg.sender, "NFTMarket: caller is not the seller");

        // 将上架信息标记为非活跃
        listing.isActive = false;

        // 触发NFT上架取消事件
        emit NFTListingCancelled(_listingId);
    }

    /**
     * @notice 普通购买 NFT（需要提前授权代币）
     * @param _listingId 上架 ID
     *
     * @dev 执行流程：
     * 1. 验证上架信息存在且处于活跃状态
     * 2. 验证买家有足够的代币余额
     * 3. 将上架标记为非活跃（防重入）
     * 4. 转移代币：买家 -> 卖家
     * 5. 转移 NFT：卖家 -> 买家
     * 6. 触发售出事件
     *
     * 前置条件：
     * - 买家必须提前授权市场合约使用代币（approve 或 permit）
     * - 卖家必须提前授权市场合约转移 NFT（approve 或 setApprovalForAll）
     *
     * 安全注意：
     * - 先标记状态再执行转账（CEI 模式，防重入）
     * - 验证代币转账结果
     * - 使用 storage 引用避免重复读取
     * - NFT 转账失败会自动 revert（ERC721 标准行为）
     *
     * Gas 优化：
     * - 使用 storage 引用而不是 memory 拷贝
     * - 先检查余额再执行转账
     */
    function buyNFT(uint256 _listingId) external {
        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");

        // 检查买家是否有足够的代币
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");

        // 将上架信息标记为非活跃
        listing.isActive = false;

        // 处理代币转账（买家 -> 卖家）
        bool success = paymentToken.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "NFTMarket: token transfer failed");

        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        // 触发NFT售出事件
        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    /**
     * @notice ERC1363 回调函数：接收代币并完成 NFT 购买
     * @param operator 调用转账的人（通常是买家）
     * @param from 付款人（买家）
     * @param amount 支付金额
     * @param data 附加数据（编码的 listingId）
     * @return 返回函数选择器，表示成功接收
     *
     * @dev ERC1363 购买流程：
     * 1. 买家调用 paymentToken.transferAndCall(marketAddress, price, abi.encode(listingId))
     * 2. 代币合约转移代币到市场合约
     * 3. 代币合约回调市场合约的 onTransferReceived 函数
     * 4. 市场合约验证并完成 NFT 转移
     *
     * 执行流程：
     * 1. 验证调用者是支付代币合约（防止伪造回调）
     * 2. 解析附加数据，获取 listingId
     * 3. 验证上架信息存在且处于活跃状态
     * 4. 验证支付金额等于 NFT 价格
     * 5. 将上架标记为非活跃（防重入）
     * 6. 转移代币：市场合约 -> 卖家
     * 7. 转移 NFT：卖家 -> 买家
     * 8. 触发售出事件
     * 9. 返回函数选择器
     *
     * 优势：
     * - 一步完成：买家只需调用一次 transferAndCall
     * - 无需授权：不需要提前 approve 市场合约
     * - 原子性：代币转移和 NFT 购买在同一交易中完成
     * - Gas 优化：减少一次交易（省去 approve）
     *
     * 安全注意：
     * - 必须验证 msg.sender 是支付代币合约（防止伪造回调）
     * - 必须验证支付金额等于价格（防止支付不足）
     * - 先标记状态再执行转账（防重入）
     * - 验证代币转账结果
     * - 必须返回正确的函数选择器
     *
     * 数据格式：
     * - data 必须是 32 字节（uint256 的 ABI 编码）
     * - 使用 abi.encode(listingId) 编码
     * - 使用 abi.decode(data, (uint256)) 解码
     */
    function onTransferReceived(
        address operator,     // 调用转账的人（通常是买家）
        address from,         // 付款人（买家）
        uint256 amount,       // 支付金额
        bytes calldata data   // 附加数据（我们编码 listingId）
    ) external override returns (bytes4) {
        // 检查调用者是否为支付代币合约
        require(msg.sender == address(paymentToken), "NFTMarket: caller is not the payment token contract");

        // 解析附加数据，获取listingId
        require(data.length == 32, "NFTMarket: invalid data length");
        uint256 listingId = abi.decode(data, (uint256));

        // 检查上架信息是否存在且处于活跃状态
        Listing storage listing = listings[listingId];
        require(listing.isActive, "onTransferReceived: listing is not active");

        // 检查转入的代币数量是否等于NFT价格
        require(amount == listing.price, "NFTMarket: incorrect payment amount");

        // 将上架信息标记为非活跃
        listing.isActive = false;

        // 将代币转给卖家
        bool success = paymentToken.transfer(listing.seller, amount);
        require(success, "NFTMarket: token transfer to seller failed");

        // 处理NFT转移（卖家 -> 买家）
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        // 触发NFT售出事件
        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);

        return this.onTransferReceived.selector;
    }

}