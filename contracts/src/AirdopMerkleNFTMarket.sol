// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/*
实现一个 AirdopMerkleNFTMarket 合约(假定 Token、NFT、AirdopMerkleNFTMarket 都是同一个开发者开发)，功能如下：
    1.基于 Merkel 树验证某用户是否在白名单中
    2.在白名单中的用户可以使用上架（和之前的上架逻辑一致）指定价格的优惠 50% 的Token 来购买 NFT， Token 需支持 permit 授权。
要求使用 multicall( delegateCall 方式) 一次性调用两个方法：
    1.permitPrePay() : 调用token的 permit 进行授权
    2.claimNFT() : 通过默克尔树验证白名单，并利用 permitPrePay 的授权，转入 token 转出 NFT 。
*/
contract AirdopMerkleNFTMarket is IERC1363Receiver {
    IERC20 public immutable paymentToken;
    bytes32 public merkleRoot;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // 记录已经使用白名单优惠的地址
    mapping(address => bool) public hasUsedWhitelist;

    event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event NFTListingCancelled(uint256 indexed listingId);
    event WhitelistNFTClaimed(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);

    constructor(address _paymentTokenAddress, bytes32 _merkleRoot) {
        require(_paymentTokenAddress != address(0), "AirdopMerkleNFTMarket: payment token address cannot be zero");
        paymentToken = IERC20(_paymentTokenAddress);
        merkleRoot = _merkleRoot;
    }

    // 更新默克尔树根（仅限管理员，实际实现中应添加访问控制）
    function updateMerkleRoot(bytes32 _merkleRoot) external {
        // 在实际实现中应添加访问控制
        merkleRoot = _merkleRoot;
    }

    // 验证地址是否在白名单中
    function isWhitelisted(address user, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verifyCalldata(proof, merkleRoot, leaf);
    }

    // 上架NFT（与NFT_Market.sol中的上架逻辑一致）
    function list(address _nftContract, uint256 _tokenId, uint256 _price) external returns (uint256) {
        require(_price > 0, "AirdopMerkleNFTMarket: price must be greater than zero");
        require(_nftContract != address(0), "AirdopMerkleNFTMarket: NFT contract address cannot be zero");

        IERC721 nftContract = IERC721(_nftContract);
        address owner = nftContract.ownerOf(_tokenId);
        require(
            owner == msg.sender ||
            nftContract.isApprovedForAll(owner, msg.sender) ||
            nftContract.getApproved(_tokenId) == msg.sender,
            "AirdopMerkleNFTMarket: caller is not owner nor approved"
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

    function cancelListing(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(listing.seller == msg.sender, "AirdopMerkleNFTMarket: caller is not the seller");

        listing.isActive = false;
        emit NFTListingCancelled(_listingId);
    }

    function buyNFT(uint256 _listingId) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "AirdopMerkleNFTMarket: insufficient token balance");

        listing.isActive = false;

        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit NFTSold(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, listing.price);
    }

    function onTransferReceived(address operator, address from, uint256 value, bytes calldata data) external override returns (bytes4) {
        require(operator == address(paymentToken), "AirdopMerkleNFTMarket: caller is not the payment token contract");
        require(data.length == 32, "AirdopMerkleNFTMarket: invalid data length");

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage listing = listings[listingId];

        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");
        require(value == listing.price, "AirdopMerkleNFTMarket: incorrect payment amount");

        listing.isActive = false;

        require(paymentToken.transfer(listing.seller, value), "AirdopMerkleNFTMarket: token transfer to seller failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, from, listing.tokenId);

        emit NFTSold(listingId, from, listing.seller, listing.nftContract, listing.tokenId, value);
        return IERC1363Receiver.onTransferReceived.selector;
    }

    // 白名单用户使用permit授权并购买NFT的multicall实现
    struct Call {
        address target;
        bytes callData;
    }

    // 使用delegateCall方式的multicall
    // 或使用：https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Multicall.sol
    function multicall(Call[] memory calls) public returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.delegatecall(calls[i].callData);
            require(success, "AirdopMerkleNFTMarket: delegatecall failed");
            results[i] = result;
        }
        return results;
    }

    // 调用token的permit进行授权
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(paymentToken)).permit(owner, spender, value, deadline, v, r, s);
    }

    // 通过默克尔树验证白名单，并利用permitPrePay的授权，转入token转出NFT
    function claimNFT(uint256 _listingId, bytes32[] calldata merkleProof) external {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "AirdopMerkleNFTMarket: listing is not active");

        // 验证用户是否在白名单中
        require(isWhitelisted(msg.sender, merkleProof), "AirdopMerkleNFTMarket: not in whitelist");
        require(!hasUsedWhitelist[msg.sender], "AirdopMerkleNFTMarket: whitelist discount already used");

        // 计算50%优惠后的价格
        uint256 discountedPrice = listing.price / 2;
        require(paymentToken.balanceOf(msg.sender) >= discountedPrice, "AirdopMerkleNFTMarket: insufficient token balance");

        // 标记该用户已使用白名单优惠
        hasUsedWhitelist[msg.sender] = true;
        listing.isActive = false;

        // 转移代币和NFT
        require(paymentToken.transferFrom(msg.sender, listing.seller, discountedPrice), "AirdopMerkleNFTMarket: token transfer failed");
        IERC721(listing.nftContract).transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit WhitelistNFTClaimed(_listingId, msg.sender, listing.seller, listing.nftContract, listing.tokenId, discountedPrice);
    }
}