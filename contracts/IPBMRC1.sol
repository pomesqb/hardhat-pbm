// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IPBMRC1 {
    event MerchantPayment(address indexed from, address indexed to, uint256[] tokenIds, uint256[] amounts, address spotToken, uint256 spotTokenAmount);
    event PBMrevokeWithdraw(address indexed revoker, uint256 tokenId, address spotToken, uint256 spotTokenAmount);
    function owner() external view returns (address owner_);
    function transferOwnership(address _newOwner) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
    function revokePBM(uint256 tokenId) external;
    function uri(uint256 tokenId) external view returns (string memory);
}