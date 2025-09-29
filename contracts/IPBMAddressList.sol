// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPBMAddressList {
    event BlacklistAddresses(address[] addresses, string metadata);
    event UnBlacklistAddresses(address[] addresses, string metadata);
    event AddMerchantAddresses(address[] addresses, string metadata);
    event RemoveMerchantAddresses(address[] addresses, string metadata);
    event WhitelistAddresses(address[] addresses, string metadata);
    event UnWhitelistAddresses(address[] addresses, string metadata);

    function isBlacklisted(address account) external view returns (bool);
    function isMerchant(address account) external view returns (bool);
    function isWhitelisted(address account) external view returns (bool);
}