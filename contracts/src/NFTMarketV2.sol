// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1363.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title NFTMarketV2
 * @notice NFT 市场合约 V2 版本，在 V1 基础上新增签名上架功能
 * @dev 可升级合约，使用 UUPS 代理模式
 *
 * V2 新增功能：
 * - 签名上架：用户可以通过签名授权他人代为上架 NFT
 * - 签名防重放：记录已使用的签名，防止重复使用
 * - 签名过期机制：签名包含截止时间，过期后无效
 *
 * 继承自 V1 的功能：
 * - NFT 上架、购买、取消上架
 * - 支持 ERC1363 的 transferAndCall 购买
 * - 可升级合约（UUPS 代理模式）
 *
 * 签名上架流程：
 * 1. 用户在链下签名授权上架信息（NFT地址、tokenId、价格、截止时间）
 * 2. 任何人可以提交签名和上架信息到合约
 * 3. 合约验证签名有效性和授权
 * 4. 合约代为上架 NFT
 *
 * 签名安全：
 * - 使用 EIP-191 标准签名（eth_sign）
 * - 签名包含合约地址，防止跨合约重放
 * - 签名包含截止时间，防止过期使用
 * - 记录已使用签名，防止重复使用
 * - 验证 NFT 所有权和授权
 *
 * 升级兼容性：
 * - 存储布局与 V1 兼容
 * - 新增 usedSignatures 映射
 * - 不影响 V1 的现有功能
 */
contract NFTMarketV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC1363Receiver {
    using ECDSA for bytes32;

    /// @notice 支付代币合约（ERC1363 标准）
    IERC1363 public paymentToken;

    /// @notice NFT 上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT 合约地址
        uint256 tokenId;     // NFT 的 tokenId
        uint256 price;       // 价格（以 paymentToken 为单位）
        bool isActive;       // 是否处于活跃状态
    }

    /// @notice 所有上架的 NFT
    mapping(uint256 => Listing) public listings;

    /// @notice 下一个可用的 listingId
    uint256 public nextListingId;

    /// @notice 用于跟踪已使用的签名（防重放攻击）
    /// @dev key 是签名的 ethSignedMessageHash，value 是是否已使用
    mapping(bytes32 => bool) public usedSignatures;

    /// @notice NFT 上架事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);

    /// @notice NFT 售出事件
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    /// @notice NFT 上架取消事件
    event NFTListingCancelled(uint256 indexed listingId);

    /**
     * @notice 构造函数
     * @dev 禁用逻辑合约的初始化器
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice 初始化函数（V2 版本）
     * @param _paymentTokenAddress 支付代币合约地址
     * @dev V2 初始化与 V1 相同，保持兼容性
     */
    function initialize(address _paymentTokenAddress) public initializer {
        __Context_init();
        __Ownable_init(msg.sender);
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        paymentToken = IERC1363(_paymentTokenAddress);
    }

    /**
     * @notice 授权升级函数
     * @param newImplementation 新的逻辑合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice 上架 NFT（与 V1 相同）
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT 的 tokenId
     * @param _price 价格
     * @return listingId 上架 ID
     */
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "NFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "NFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender ||
            nftContract.isApprovedForAll(owner, msg.sender) ||
            nftContract.getApproved(_tokenId) == msg.sender,
            "NFTMarket: caller is not owner nor approved"
        );

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
        return listingId;
    }

    /**
     * @notice 使用签名上架 NFT（V2 新增功能）
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT 的 tokenId
     * @param _price 上架价格
     * @param _deadline 签名有效期（Unix 时间戳）
     * @param _signature 用户签名（EIP-191 标准）
     * @return listingId 上架 ID
     *
     * @dev 执行流程：
     * 1. 验证价格、地址、截止时间
     * 2. 获取 NFT 当前所有者
     * 3. 生成消息哈希并验证签名
     * 4. 验证签名者是 NFT 所有者
     * 5. 验证签名未被使用过
     * 6. 验证市场合约已获得授权
     * 7. 标记签名为已使用
     * 8. 创建上架信息
     * 9. 触发上架事件
     *
     * 签名生成（链下）：
     * 1. 生成消息哈希：keccak256(abi.encodePacked(marketAddress, nftContract, tokenId, price, deadline))
     * 2. 添加 EIP-191 前缀："\x19Ethereum Signed Message:\n32" + messageHash
     * 3. 使用私钥签名：eth_sign(ethSignedMessageHash)
     *
     * 安全机制：
     * - 签名包含合约地址，防止跨合约重放
     * - 签名包含截止时间，防止过期使用
     * - 记录已使用签名，防止重复使用
     * - 验证 NFT 所有权和授权
     *
     * 使用场景：
     * - 批量上架：用户签名多个 NFT，他人批量提交
     * - 延迟上架：用户提前签名，稍后上架
     * - 代理上架：用户授权他人代为上架
     * - Gas 优化：用户只需签名，无需支付 Gas
     */
    function listWithSignature(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes memory _signature
    ) external returns (uint256) {
        require(_price > 0, "NFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "NFTMarket: NFT contract address cannot be zero");
        require(block.timestamp <= _deadline, "NFTMarket: signature expired");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);

        // 验证签名
        bytes32 messageHash = getListingMessageHash(_nftContract, _tokenId, _price, _deadline);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, _signature);

        require(signer == owner, "NFTMarket: invalid signature");
        require(!usedSignatures[ethSignedMessageHash], "NFTMarket: signature already used");
        require(nftContract.isApprovedForAll(owner, address(this)), "NFTMarket: market not approved");

        // 标记签名为已使用
        usedSignatures[ethSignedMessageHash] = true;

        uint256 listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: owner,
            nftContract: _nftContract,
            tokenId: _tokenId,
            price: _price,
            isActive: true
        });

        emit NFTListed(listingId, owner, _nftContract, _tokenId, _price);
        return listingId;
    }

    /**
     * @notice 生成用于签名的消息哈希
     * @param _nftContract NFT 合约地址
     * @param _tokenId NFT 的 tokenId
     * @param _price 上架价格
     * @param _deadline 签名有效期
     * @return 消息哈希（未添加 EIP-191 前缀）
     *
     * @dev 消息哈希包含：
     * - 合约地址：防止跨合约重放
     * - NFT 合约地址：指定 NFT
     * - tokenId：指定具体的 NFT
     * - 价格：指定上架价格
     * - 截止时间：防止过期使用
     *
     * 注意：
     * - 此函数返回的是原始消息哈希
     * - 签名时需要添加 EIP-191 前缀
     * - 使用 MessageHashUtils.toEthSignedMessageHash 添加前缀
     */
    function getListingMessageHash(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                address(this),
                _nftContract,
                _tokenId,
                _price,
                _deadline
            )
        );
    }

    /**
     * @notice 取消上架 NFT（与 V1 相同）
     * @param _listingId 上架 ID
     */
    function cancelListing(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        require(listing.seller == msg.sender, "NFTMarket: caller is not the seller");

        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }

    /**
     * @notice 购买 NFT（与 V1 相同）
     * @param _listingId 上架 ID
     */
    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "NFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");

        listing.isActive = false;

        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    /**
     * @notice ERC1363 回调函数：接收代币并完成 NFT 购买（与 V1 相同）
     * @param operator 调用转账的人
     * @param from 付款人（买家）
     * @param amount 支付金额
     * @param data 附加数据（编码的 listingId）
     * @return 返回函数选择器
     */
    function onTransferReceived(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(paymentToken), "NFTMarket: caller is not the payment token contract");
        require(data.length == 32, "NFTMarket: invalid data length");

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage listing = listings[listingId];

        require(listing.isActive, "NFTMarket: listing is not active");
        require(amount == listing.price, "NFTMarket: incorrect payment amount");

        listing.isActive = false;

        require(paymentToken.transfer(listing.seller, amount), "NFTMarket: token transfer to seller failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, amount);

        return this.onTransferReceived.selector;
    }

    /**
     * @notice 检查合约是否支持指定的接口
     * @param interfaceId 接口 ID
     * @return 如果支持该接口返回 true
     * @dev 支持的接口：
     * - IERC165: 0x01ffc9a7
     * - IERC1363Receiver: 0x88a7ca5c
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
                interfaceId == type(IERC165).interfaceId ||
                interfaceId == type(IERC1363Receiver).interfaceId;
    }

}