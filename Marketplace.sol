// SPDX-License-Identifier: MIT LICENSE

// Usar o TheGraph para retornar dados indexados dos NFT para uma possível listagem no frontend

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Marketplace is ERC721Holder, ReentrancyGuard, Ownable, Pausable {
    IERC721 public immutable NFT_ADDRESS;
    uint256 listingFee = 0.0025 ether;

    /// @notice A struct describing an nft in the list
    struct List {
        uint256 tokenId;
        address payable seller;
        address payable holder;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => List) public salesList;
    mapping(uint256 => bool) public listed;

    event NFTListCreated(uint256 indexed tokenId, address seller, address holder, uint256 price, bool sold);
    event UpdatedListingFee(uint256 newListingFee);
    event withdrawalMade(address indexed to, uint256 value);

    error NotOwnerThisNFT();
    error NFTAlreadyListed();
    error PayAtLeastTheListingFee();
    error InsufficientValue();
    error InsufficientFeeOrPrice();
    error FailedTransfer();
    error BalanceMustBeGreaterThanZero();
    error AddressCannotBeZero();

    constructor(address _nft, address initialOwner) Ownable(initialOwner) {
        NFT_ADDRESS = IERC721(_nft);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function sale(uint256 tokenId, uint256 price) public payable nonReentrant whenNotPaused {
        if (NFT_ADDRESS.ownerOf(tokenId) != msg.sender) {
            revert NotOwnerThisNFT();
        }

        if (listed[tokenId]) {
            revert NFTAlreadyListed();
        }

        if (price == 0) {
            revert InsufficientFeeOrPrice();
        }

        if (msg.value < listingFee) {
            revert InsufficientFeeOrPrice();
        }

        listed[tokenId] = true;
        salesList[tokenId] = List(tokenId, payable(msg.sender), payable(address(this)), price, false);
        //Before calling the transfer function, you must call the approve function in the frontend
        NFT_ADDRESS.transferFrom(msg.sender, address(this), tokenId);
        emit NFTListCreated(tokenId, msg.sender, address(this), price, false);
    }

    function buy(uint256 tokenId) public payable nonReentrant whenNotPaused {
        uint256 price = salesList[tokenId].price;

        if (msg.value < price) {
            revert InsufficientValue();
        }

        address payable seller = salesList[tokenId].seller;
    
        if(seller == address(0)){
            revert AddressCannotBeZero();
        }

        (bool success,) = seller.call{value: msg.value}("");
        if(!success){
            revert FailedTransfer();
        }

        delete salesList[tokenId];
        delete listed[tokenId];
        //Before calling the transfer function, you must call the approve function in the frontend
        NFT_ADDRESS.transferFrom(address(this), msg.sender, tokenId);
    }

    function cancelSale(uint256 tokenId) public nonReentrant {
        if(salesList[tokenId].seller != msg.sender){
            revert NotOwnerThisNFT();
        }

        delete salesList[tokenId];
        NFT_ADDRESS.transferFrom(address(this), msg.sender, tokenId);
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;

        if (balance <= 0) {
            revert BalanceMustBeGreaterThanZero();
        }

        (bool success,) = msg.sender.call{value: balance}(""); 
        if (!success) {
            revert FailedTransfer();
        }

        emit withdrawalMade(msg.sender, balance);
    }

    ///@notice Updates the listing fee (should emit an event)
    function updateListingFee(uint256 _listingFee) public onlyOwner {
        listingFee = _listingFee;
        emit UpdatedListingFee(_listingFee);
    }

    function getPrice(uint256 tokenId) public view returns (uint256) {
        uint256 price = salesList[tokenId].price;
        return price;
    }

    function getListingFee() public view returns (uint256) {
        return listingFee;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
