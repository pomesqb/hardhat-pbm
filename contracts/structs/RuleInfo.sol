// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../enums/PBMType.sol";

struct RuleInfo {
    PBMType pbmType;
    uint256 timeLockTimestamp;
    uint256 exchangeRate; // 例如 31527500 代表 31.5275
}
