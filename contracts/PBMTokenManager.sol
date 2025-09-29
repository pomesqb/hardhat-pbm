// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPBMTokenManager.sol";

contract PBMTokenManager is IPBMTokenManager, Ownable {
    uint256 public tokenTypeCount;
    string public URIPostExpiry;
    mapping(uint256 => TokenConfig) public tokenTypes;

    constructor(string memory _uriPostExpiry) Ownable(msg.sender) {
        tokenTypeCount = 1;
        URIPostExpiry = _uriPostExpiry;
    }

    function createTokenType(
        string memory tokenName,
        uint256 spotAmount,
        uint256 tokenExpiry,
        address creator,
        string memory tokenURI,
        uint256 contractExpiry
    ) external override onlyOwner returns (uint256 tokenId) {
        require(tokenExpiry <= contractExpiry, "Invalid token expiry-1");
        require(tokenExpiry > block.timestamp, "Invalid token expiry-2");
        require(spotAmount != 0, "Spot amount is 0");
        tokenTypes[tokenTypeCount] = TokenConfig(
            tokenName,
            spotAmount,
            0,
            tokenExpiry,
            creator,
            tokenURI
        );

        tokenId = tokenTypeCount;
        tokenTypeCount += 1;
    }

    function revokePBM(
        uint256 tokenId,
        address sender
    ) external override onlyOwner {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        require(areTokensValid(tokenIds), "PBM: Invalid token");
        require(
            block.timestamp > tokenTypes[tokenId].expiry,
            "PBM: Token not expired"
        );
        require(sender == tokenTypes[tokenId].creator, "PBM: Not creator");
        tokenTypes[tokenId].balanceSupply = 0;
    }

    function increaseBalanceSupply(
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external override onlyOwner {
        require(tokenIds.length == amounts.length, "Array length mismatch");
        require(areTokensValid(tokenIds), "PBM: Invalid token");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenTypes[tokenIds[i]].balanceSupply += amounts[i];
        }
    }

    function decreaseBalanceSupply(
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) external override onlyOwner {
        require(tokenIds.length == amounts.length, "Array length mismatch");
        require(areTokensValid(tokenIds), "PBM: Invalid token");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenTypes[tokenIds[i]].balanceSupply -= amounts[i];
        }
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (block.timestamp > tokenTypes[tokenId].expiry) {
            return URIPostExpiry;
        } else {
            return tokenTypes[tokenId].uri;
        }
    }

    function areTokensValid(
        uint256[] memory tokenIds
    ) public view returns (bool) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == 0 || tokenIds[i] >= tokenTypeCount) return false;
        }
        return true;
    }

    function getPBMRevokeValue(
        uint256 tokenId
    ) public view override returns (uint256) {
        return tokenTypes[tokenId].balanceSupply * tokenTypes[tokenId].amount;
    }

    function getTokenDetails(
        uint256 tokenId
    )
        external
        view
        override
        returns (string memory, uint256, uint256, uint256, address)
    {
        return (
            tokenTypes[tokenId].name,
            tokenTypes[tokenId].amount,
            tokenTypes[tokenId].balanceSupply,
            tokenTypes[tokenId].expiry,
            tokenTypes[tokenId].creator
        );
    }

    function getTokenValue(
        uint256 tokenId
    ) public view override returns (uint256) {
        return tokenTypes[tokenId].amount;
    }

    function getTokenIdByTypeName(
        string memory tokenTypeName,
        uint256 spotAmount
    ) external view override returns (uint256) {
        for (uint256 i = 1; i < tokenTypeCount; i++) {
            if (
                keccak256(abi.encodePacked(tokenTypes[i].name)) ==
                keccak256(abi.encodePacked(tokenTypeName)) &&
                tokenTypes[i].amount == spotAmount
            ) {
                return i;
            }
        }
        return 0;
    }
}
