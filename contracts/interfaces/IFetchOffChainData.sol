// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IFetchOffChainData {
    function sendRequest(
        string calldata transactionId,
        uint256 amount,
        address custodian
    ) external returns (bytes32);
}
