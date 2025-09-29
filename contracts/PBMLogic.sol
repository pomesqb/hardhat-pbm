// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IPBMAddressList.sol";

abstract contract PBMLogic is IPBMAddressList {
    address public owner;
    mapping(address => bool) public isBlacklistedAddress;
    mapping(address => bool) public isMerchantAddress;
    mapping(address => bool) public isWhitelistedAddress;

    constructor() { owner = msg.sender; }

    modifier onlyOwner() { require(owner == msg.sender, "PBM: caller is not the owner"); _; }

    function isBlacklisted(address _account) external view override returns (bool) { return isBlacklistedAddress[_account]; }
    function isMerchant(address _account) external view override returns (bool) { return isMerchantAddress[_account]; }
    function isWhitelisted(address _account) external view override returns (bool) { return isWhitelistedAddress[_account]; }

    function blacklistAddresses(address[] memory _accounts) external onlyOwner { for (uint256 i = 0; i < _accounts.length; i++) { isBlacklistedAddress[_accounts[i]] = true; } emit BlacklistAddresses(_accounts, "Blacklisted"); }
    function unBlacklistAddresses(address[] memory _accounts) external onlyOwner { for (uint256 i = 0; i < _accounts.length; i++) { isBlacklistedAddress[_accounts[i]] = false; } emit UnBlacklistAddresses(_accounts, "Unblacklisted"); }
    function addMerchantAddresses(address[] memory _accounts) external onlyOwner { for (uint256 i = 0; i < _accounts.length; i++) { isMerchantAddress[_accounts[i]] = true; } emit AddMerchantAddresses(_accounts, "Merchants Added"); }
    function removeMerchantAddresses(address[] memory _accounts) external onlyOwner { for (uint256 i = 0; i < _accounts.length; i++) { isMerchantAddress[_accounts[i]] = false; } emit RemoveMerchantAddresses(_accounts, "Merchants Removed"); }

    function transferPreCheck(address _from, address _to, uint256 _tokenId) external view virtual returns (bool);
    function unwrapPreCheck(address _unwrapper, uint256 _tokenId, bytes calldata _data) external view virtual returns (bool);
}