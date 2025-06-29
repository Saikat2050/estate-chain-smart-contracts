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

    struct Lease {
        address lessee;
        uint256 percentage;
        uint256 leaseStart;
        uint256 leaseEnd;
        uint256 leasePrice;
    }

    mapping(uint256 => Lease[]) public propertyLeases;

    event PropertyMinted(address indexed creator, uint256 indexed tokenId, string uri);
    event PropertyPurchased(address indexed buyer, uint256 indexed tokenId, uint256 amount, uint256 ethPaid);
    event LandLeased(address indexed lessee, uint256 indexed tokenId, uint256 percentage, uint256 leaseStart, uint256 leaseEnd, uint256 leasePrice);

    constructor(address _priceFeed) ERC1155("") Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

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

        emit PropertyMinted(msg.sender, tokenId, uri_);
    }

    function setTokenURI(uint256 tokenId, string memory newURI) external {
        require(msg.sender == properties[tokenId].creator, "Only creator can update URI");
        properties[tokenId].uri = newURI;
    }

    function purchase(uint256 tokenId, uint256 amount) external payable {
        Property storage p = properties[tokenId];
        require(p.supply > 0, "Invalid tokenId");
        require(p.supply >= amount, "Not enough supply");

        uint256 ethRequired = getTokenPriceInETH(p.priceInUsd, amount);
        require(msg.value >= ethRequired, "Not enough ETH sent");

        _safeTransferFrom(p.creator, msg.sender, tokenId, amount, "");

        payable(p.creator).transfer(ethRequired);

        if (msg.value > ethRequired) {
            payable(msg.sender).transfer(msg.value - ethRequired);
        }

        p.supply -= amount;

        emit PropertyPurchased(msg.sender, tokenId, amount, ethRequired);
    }

    function leaseLand(
        uint256 tokenId,
        uint256 periodDays,
        uint256 percentage,
        uint256 leasePriceInUsd
    ) external payable {
        require(properties[tokenId].supply > 0, "Invalid tokenId");

        uint256 ethRequired = getTokenPriceInETH(leasePriceInUsd, percentage);
        require(msg.value >= ethRequired, "Insufficient ETH");

        propertyLeases[tokenId].push(
            Lease({
                lessee: msg.sender,
                percentage: percentage,
                leaseStart: block.timestamp,
                leaseEnd: block.timestamp + (periodDays * 1 days),
                leasePrice: ethRequired
            })
        );

        payable(properties[tokenId].creator).transfer(ethRequired);

        emit LandLeased(msg.sender, tokenId, percentage, block.timestamp, block.timestamp + (periodDays * 1 days), ethRequired);
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
        // Assume USD has 8 decimals from Chainlink feed
        return (usdPrice * amount * 1e18) / uint256(ethPrice);
    }
}
