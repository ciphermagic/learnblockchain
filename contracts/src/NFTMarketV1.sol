pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1363.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// NFT市场合约
contract NFTMarketV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC1363Receiver {
    IERC1363 public paymentToken;

    // NFT上架信息结构体
    struct Listing {
        address seller;      // 卖家地址
        address nftContract; // NFT合约地址
        uint256 tokenId;     // NFT的tokenId
        uint256 price;       // 价格（以Token为单位）
        bool isActive;       // 是否处于活跃状态
    }

    // 所有上架的NFT，使用listingId作为唯一标识
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // NFT上架和购买事件
    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _paymentTokenAddress) public initializer {
        require(_paymentTokenAddress != address(0), "NFTMarket: payment token address cannot be zero");
        paymentToken = IERC1363(_paymentTokenAddress);

        __Ownable_init(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 上架NFT
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

    // 取消上架NFT
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

    // 普通购买NFT功能
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