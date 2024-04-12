// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMarketplace is ERC721Holder, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _totalListings;
    Counters.Counter private _totalSales;

    uint256 public feePercentage;
    uint256 private constant PERCENTAGE_BASE = 100;

    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }

    mapping(address => mapping(uint256 => Listing)) private listings;

    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event NFTPriceChanged(address indexed seller, uint256 indexed tokenId, uint256 newPrice);
    event NFTUnlisted(address indexed seller, uint256 indexed tokenId);

    constructor() {
        feePercentage = 2;
    }

    function listNFT(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        _totalListings.increment();

        emit NFTListed(msg.sender, tokenId, price);
    }

    function buyNFT(address nftContract, uint256 tokenId) external payable {
        Listing storage listing = listings[nftContract][tokenId];
        
        require(listing.isActive, "NFT is not listed for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 feeAmount = (listing.price * feePercentage) / PERCENTAGE_BASE;
        uint256 sellerAmount = listing.price - feeAmount;
        payable(owner()).transfer(feeAmount);
        payable(listing.seller).transfer(sellerAmount);

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        listing.isActive = false;
        _totalSales.increment();

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    function changePrice(address nftContract, uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than zero");
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        listings[nftContract][tokenId].price = newPrice;

        emit NFTPriceChanged(msg.sender, tokenId, newPrice);
    }

    function unlistNFT(address nftContract, uint256 tokenId) external {
        require(listings[nftContract][tokenId].seller == msg.sender, "You are not the seller");

        delete listings[nftContract][tokenId];

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        _totalListings.decrement();

        emit NFTUnlisted(msg.sender, tokenId);
    }

    function setFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage < PERCENTAGE_BASE, "Fee percentage must be less than 100");

        feePercentage = newFeePercentage;
    }

    // Function to get the total number of listings on the marketplace
    function getTotalListings() external view returns (uint256) {
        return _totalListings.current();
    }

    // Function to get the total number of sales on the marketplace
    function getTotalSales() external view returns (uint256) {
        return _totalSales.current();
    }
}