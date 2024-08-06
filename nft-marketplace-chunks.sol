// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC721Interface.sol";
import "./ERC20Interface.sol";
import "./ERC1155Interface.sol";
import {Verification} from "./Verification.sol";

contract MyntistNFTMarketplace is Initializable, UUPSUpgradeable, OwnableUpgradeable, Verification {
    address wbnbAddress;
    address myntistTokenAddress;
    using SafeMath for uint256;
    mapping(address => mapping(uint256 => bool)) seenNonces;
    struct mint721Data {
        string metadata;
        address payable owner;
        address nft;
    }
    struct mint1155Data {
        address payable owner;
        address nft;
        uint256 amount;
    }
    struct acceptOfferBid1155Data {
        uint8 acceptType;
        string metadata;
        uint256 tokenId;
        address newOwner;
        uint256 quantity;
        uint256 totalQuantity;
        address nft;
        bytes signature;
        uint payThrough;
        uint256 amount;
        uint256 percent;
        uint256 collectionId;
        string encodeKey;
        uint256 nonce;
        Royalty[] nftRoyalty;
        uint256 platformShareAmount;
        uint256 ownerShare;
        uint256 stakeIndex;
        bool stakeExists;
    }
    struct Royalty {
        uint256 amount;
        address wallet;
    }
    struct RoyaltyResponse {
        uint256 amount;
        address wallet;
    }
    struct buy721Data {
        string metadata;
        uint256 tokenId;
        address owner;
        address nft;
        bytes signature;
        uint payThrough;
        uint256 amount;
        uint256 percent;
        uint256 collectionId;
        string encodeKey;
        uint256 nonce;
        Royalty[] nftRoyalty;
        uint256 ownerShare;
        uint8 currency;
        uint256 stakeIndex;
        bool stakeExists;
    }
    struct acceptData1155 {
        string metadata;
        uint256 tokenId; 
        address newOwner;
        address owner;
        address nft;
        uint payThrough;
        uint256 amount;
        uint256 percent;
        uint256 collectionId;
        Royalty[] nftRoyalty;
        uint256 platformShareAmount;
        uint256 ownerShare;
        address currentOwner;
        uint256 quantity;
        uint256 totalQuantity;
    }
    struct transfer721Data {
        string metadata;
        uint256 tokenId; 
        address newOwner;
        address nft;
        uint256 amount;
        bytes signature;
        address currentOwner;
        string encodeKey;
        uint256 nonce;
    }
    event BidOfferAccepted(uint256 tokenId, uint256 price, address from, address to, uint8 acceptType);
    event Nft721Transferred(uint256 tokenId, uint256 price, address from, address to);
    event Nft1155Transferred(uint256 tokenId, uint256 price, address from, address to, uint256 quantity);
    event AutoAccepted(uint256 tokenId);
    function initialize(address mynt, address _wbnb) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        wbnbAddress = _wbnb;
        myntistTokenAddress = mynt;
	}
    function _authorizeUpgrade(address) internal override onlyOwner{}
    function mint721(mint721Data memory _nftData) internal returns (uint256) {
        IERC721Token nftToken = IERC721Token(_nftData.nft);
        uint256 tokenId = nftToken.safeMint(_nftData.owner, _nftData.metadata);
        return tokenId;
    }
    function mint1155(mint1155Data memory _nftData) internal returns (uint256) {
        IERC1155Token nftToken = IERC1155Token(_nftData.nft);
        uint256 tokenId = nftToken.mint(_nftData.amount, _nftData.owner);
        return tokenId;
    }
    function acceptOfferBid1155(acceptOfferBid1155Data memory _transferData) external payable {
        uint256 tokenId = _transferData.tokenId;
        require(!seenNonces[msg.sender][_transferData.nonce], "Invalid request");
        seenNonces[msg.sender][_transferData.nonce] = true;
        require(verify(msg.sender, msg.sender, _transferData.amount, _transferData.encodeKey, _transferData.nonce, _transferData.signature), "invalid signature");
        if(_transferData.tokenId == 0) {
            mint1155Data memory mintData = mint1155Data(
                payable(msg.sender),
                _transferData.nft,
                _transferData.totalQuantity
            );
            tokenId = mint1155(mintData);
        }
        transferRoyaltiesToken(_transferData.nftRoyalty, _transferData.payThrough, _transferData.newOwner, _transferData.platformShareAmount);
        if(_transferData.payThrough==1) {
            transferERC20ToOwner(_transferData.newOwner, msg.sender, _transferData.ownerShare, myntistTokenAddress);
        }
        else {
            transferERC20ToOwner(_transferData.newOwner, msg.sender, _transferData.ownerShare, wbnbAddress);
        }
        transfer1155(_transferData.nft, msg.sender, _transferData.newOwner, _transferData.quantity, tokenId);
        if(_transferData.stakeExists){
            transferStaking(_transferData.stakeIndex, _transferData.newOwner, msg.sender, myntistTokenAddress);
        }
        emit BidOfferAccepted(tokenId, msg.value, msg.sender, _transferData.newOwner, _transferData.acceptType);
    }
    function buy721(buy721Data memory _buyData) external payable {
        uint256 tokenId = _buyData.tokenId;
        require(!seenNonces[msg.sender][_buyData.nonce], "Invalid request");
        seenNonces[msg.sender][_buyData.nonce] = true;
        require(verify(msg.sender, msg.sender, _buyData.amount, _buyData.encodeKey, _buyData.nonce, _buyData.signature), "invalid signature");
        if(_buyData.tokenId == 0) {
            mint721Data memory mintData = mint721Data(
                _buyData.metadata,
                payable(_buyData.owner),
                _buyData.nft
            );
            tokenId = mint721(mintData);
        }
        transferRoyalties(_buyData.nftRoyalty);
        transfer721(_buyData.nft, _buyData.owner, msg.sender, tokenId);
        
        if(_buyData.currency==1) {
            payable(_buyData.owner).transfer(_buyData.ownerShare);
        }
        else if(_buyData.currency==2) {
            transferERC20ToOwner(msg.sender, _buyData.owner, _buyData.ownerShare, myntistTokenAddress);
        }
        if(_buyData.stakeExists){
            transferStaking(_buyData.stakeIndex, msg.sender, _buyData.owner, myntistTokenAddress);
        }
        emit Nft721Transferred(tokenId, msg.value, _buyData.owner, msg.sender);
    }
    function acceptBid1155(acceptData1155 memory _transferData) external payable onlyOwner {
        uint256 tokenId = _transferData.tokenId;
        if(_transferData.tokenId == 0) {
            mint1155Data memory mintData = mint1155Data(
                payable(_transferData.owner),
                _transferData.nft,
                _transferData.totalQuantity
            );
            tokenId = mint1155(mintData);
        }
        transferRoyaltiesToken(_transferData.nftRoyalty, _transferData.payThrough, _transferData.newOwner, _transferData.platformShareAmount);
        if(_transferData.payThrough==1) {
            transferERC20ToOwner(_transferData.newOwner, _transferData.owner, _transferData.ownerShare, myntistTokenAddress);
        }
        else {
            transferERC20ToOwner(_transferData.newOwner, _transferData.owner, _transferData.ownerShare, wbnbAddress);
        }
        transfer721(_transferData.nft, _transferData.owner, _transferData.newOwner, tokenId);
        emit AutoAccepted(tokenId);
    }
    function transferForFree721(transfer721Data memory _transferData) public {
        require(!seenNonces[msg.sender][_transferData.nonce], "Invalid request");
        seenNonces[msg.sender][_transferData.nonce] = true;
        require(verify(msg.sender, msg.sender, _transferData.amount, _transferData.encodeKey, _transferData.nonce, _transferData.signature), "invalid signature");
        uint256 tokenId = _transferData.tokenId;
        if(_transferData.tokenId == 0) {
            mint721Data memory mintData = mint721Data(
                _transferData.metadata,
                payable(msg.sender),
                _transferData.nft
            );
            tokenId = mint721(mintData);
        }
        transfer721(_transferData.nft, msg.sender, _transferData.newOwner, tokenId);
    }
    function transferForFree1155(transfer1155Data memory _transferData) public {
        require(!seenNonces[msg.sender][_transferData.nonce], "Invalid request");
        seenNonces[msg.sender][_transferData.nonce] = true;
        require(verify(msg.sender, msg.sender, _transferData.amount, _transferData.encodeKey, _transferData.nonce, _transferData.signature), "invalid signature");
        uint256 tokenId = _transferData.tokenId;
        if(_transferData.tokenId == 0) {
            mint1155Data memory mintData = mint1155Data(
                payable(msg.sender),
                _transferData.nft,
                _transferData.quantity
            );
            tokenId = mint1155(mintData);
        }
        transfer1155(_transferData.nft, _transferData.currentOwner, _transferData.newOwner, _transferData.quantity, tokenId);
    }
    function transfer721(address cAddress, address from, address to, uint256 token) internal {
        IERC721Token nftToken = IERC721Token(cAddress);
        nftToken.safeTransferFrom(from, to, token);
    }
    function transfer1155(address cAddress, address from, address to, uint256 amount, uint256 token) internal {
        IERC1155Token nftToken = IERC1155Token(cAddress);
        nftToken.safeTransferFrom(from, to, token, amount, "");
    }
    fallback () payable external {}
    receive () payable external {}
    function transferRoyalties(Royalty[] memory nftRoyalty) internal {
        for(uint x = 0; x < nftRoyalty.length; x++) {
            Royalty memory royalty = nftRoyalty[x];
            payable(royalty.wallet).transfer(royalty.amount);
        }
    }
    function transferRoyaltiesToken(Royalty[] memory nftRoyalty, uint256 paymentType, address buyer, uint256 platformShareAmount) internal {
        for(uint x = 0; x < nftRoyalty.length; x++) {
            Royalty memory royalty = nftRoyalty[x];
            if(paymentType==1) {
                transferERC20ToOwner(buyer, royalty.wallet, royalty.amount, myntistTokenAddress);
            }
            else {
                transferERC20ToOwner(buyer, royalty.wallet, royalty.amount, wbnbAddress);
            }
        }
        if(paymentType==1) {
            transferERC20ToOwner(buyer, address(this), platformShareAmount, myntistTokenAddress);
        }
        else {
            transferERC20ToOwner(buyer, address(this), platformShareAmount, wbnbAddress);
        }
    }
    function transferERC20ToOwner(address from, address to, uint256 amount, address tokenAddress) private {
        IERC20Token token = IERC20Token(tokenAddress);
        uint256 balance = token.balanceOf(from);
        require(balance >= amount, "insufficient balance" );
        token.transferFrom(from, to, amount);
    }
    function transferStaking(uint256 stakeIndex, address to, address from, address tokenAddress) private {
        IERC20Token token = IERC20Token(tokenAddress);
        // token.stakeTransfer(stakeIndex, to);
        token.nftStakeTransfer(stakeIndex, to, from);
    }
    function changeMyntTokenAddress(address _mynt) public onlyOwner {
        myntistTokenAddress = _mynt;
    }
    function withdrawBNB() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    function withdrawMYNT() public onlyOwner {
        IERC20Token annexToken = IERC20Token(myntistTokenAddress);
        uint256 balance = annexToken.balanceOf(address(this));
        require(balance >= 0, "insufficient balance" );
        annexToken.transfer(owner(), balance);
    }
    function withdrawWBNB() public onlyOwner {
        IERC20Token wbnb = IERC20Token(wbnbAddress);
        uint256 balance = wbnb.balanceOf(address(this));
        require(balance >= 0, "insufficient balance" );
        wbnb.transfer(owner(), balance);
    }
}
