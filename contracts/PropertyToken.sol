// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80);
}

contract PropertyToken is ERC1155, Ownable {
    AggregatorV3Interface internal priceFeed;

    struct Property {
        address creator;
        string uri;
        uint256 supply;
        uint256 priceInUsd;
    }

    mapping(uint256 => Property) public properties;
    mapping(uint256 => uint256) public totalMinted;
    uint256 public nextTokenId;

    constructor(address _priceFeed) ERC1155("") Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /// Mint a new property token
    function mintProperty(
        uint256 amount,
        uint256 priceInUsd,
        string memory uri_
    ) external {
        require(amount > 0, "Amount must be > 0");
        uint256 tokenId = ++nextTokenId;

        properties[tokenId] = Property({
            creator: msg.sender,
            uri: uri_,
            supply: amount,
            priceInUsd: priceInUsd
        });

        _mint(msg.sender, tokenId, amount, "");
        totalMinted[tokenId] = amount;
    }

    /// Purchase a token by paying ETH using Chainlink conversion
    function purchase(uint256 tokenId, uint256 amount) external payable {
        Property memory p = properties[tokenId];
        require(p.supply > 0, "Invalid tokenId");

        uint256 ethRequired = getTokenPriceInETH(p.priceInUsd, amount);
        require(msg.value >= ethRequired, "Not enough ETH sent");

        _safeTransferFrom(p.creator, msg.sender, tokenId, amount, "");

        // Send funds to original creator
        payable(p.creator).transfer(ethRequired);

        // Refund excess
        if (msg.value > ethRequired) {
            payable(msg.sender).transfer(msg.value - ethRequired);
        }
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return properties[tokenId].uri;
    }

    function getLatestETHPrice() public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price; // 8 decimals
    }

    function getTokenPriceInETH(
        uint256 usdPrice,
        uint256 amount
    ) public view returns (uint256) {
        int256 ethPrice = getLatestETHPrice();
        require(ethPrice > 0, "Invalid price");
        return (usdPrice * amount * 1e18) / uint256(ethPrice);
    }
}
