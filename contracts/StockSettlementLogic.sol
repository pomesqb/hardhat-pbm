// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PBMLogic.sol";
import "./StockSettlementPBM.sol";
import "./interfaces/IPBMTokenManager.sol";
import "./interfaces/IFetchOffChainData.sol";
import "./enums/PBMType.sol";
import "./structs/RuleInfo.sol";

contract StockSettlementLogic is PBMLogic {
    address public tdccAddress;
    address public fetchOffChainData;
    IPBMTokenManager public pbmTokenManager;
    StockSettlementPBM public stockPBM;
    mapping(address => bool) public isCustodianBank;
    mapping(uint256 => RuleInfo) public tokenRules;
    mapping(bytes32 => address) private requestToCustodian;
    mapping(bytes32 => uint256) private requestToAmount;

    modifier onlyFetcher() {
        require(msg.sender == fetchOffChainData, "Not fetcher");
        _;
    }

    constructor(address _pbmTokenManagerAddress, address _stockPBMAddress) {
        pbmTokenManager = IPBMTokenManager(_pbmTokenManagerAddress);
        stockPBM = StockSettlementPBM(_stockPBMAddress);
    }

    function setTdccAddress(address _tdcc) external onlyOwner {
        tdccAddress = _tdcc;
    }

    function setFetchOffChainData(address _fetcher) external onlyOwner {
        fetchOffChainData = _fetcher;
    }

    function requestPBMRegistration(
        string calldata _transactionId,
        uint256 _amount
    ) external {
        require(isCustodianBank[msg.sender], "Not custodian");
        require(fetchOffChainData != address(0), "Fetcher not set");

        bytes32 reqId = IFetchOffChainData(fetchOffChainData).sendRequest(
            _transactionId,
            _amount,
            msg.sender
        );
        requestToCustodian[reqId] = msg.sender;
        requestToAmount[reqId] = _amount;
    }

    // 由 FetchOffChainData fulfill 後回呼
    function handleFulfilledPBMRequest(
        address custodian,
        uint256 amount,
        uint256 settlementTimestamp,
        uint256 exchangeRate
    ) external onlyFetcher {
        string memory tokenName;
        uint256 tokenExpiry;
        PBMType pbmType;

        if (settlementTimestamp > 0) {
            require(
                settlementTimestamp > block.timestamp,
                "Settlement in past"
            );
            tokenName = "Settlement PBM";
            tokenExpiry = settlementTimestamp + 365 days;
            pbmType = PBMType.Settlement;
        } else {
            tokenName = "Frozen PBM";
            tokenExpiry = block.timestamp + 365 days;
            pbmType = PBMType.Frozen;
        }

        uint256 newTokenId = stockPBM.executeMintFromLogic(
            tokenName,
            custodian,
            custodian,
            amount,
            tokenExpiry,
            ""
        );
        registerRule(newTokenId, pbmType, settlementTimestamp, exchangeRate);
    }

    function registerRule(
        uint256 _tokenId,
        PBMType _pbmType,
        uint256 _timeLockTimestamp,
        uint256 _exchangeRate
    ) public {
        require(
            msg.sender == address(stockPBM) || msg.sender == address(this),
            "Unauthorized caller"
        );
        tokenRules[_tokenId] = RuleInfo({
            pbmType: _pbmType,
            timeLockTimestamp: _timeLockTimestamp,
            exchangeRate: _exchangeRate
        });
    }

    function unwrapPreCheck(
        address _unwrapper,
        uint256 _tokenId,
        bytes calldata
    ) external view override returns (bool) {
        RuleInfo memory rules = tokenRules[_tokenId];
        if (rules.pbmType == PBMType.None) return false;
        if (
            rules.pbmType != PBMType.Frozen &&
            block.timestamp < rules.timeLockTimestamp
        ) return false;
        if (rules.pbmType == PBMType.Settlement)
            return _unwrapper == tdccAddress;
        if (rules.pbmType == PBMType.Remittance)
            return isCustodianBank[_unwrapper];
        if (rules.pbmType == PBMType.Frozen) return false;
        return false;
    }

    function transferPreCheck(
        address,
        address,
        uint256 _tokenId
    ) external view override returns (bool) {
        if (tokenRules[_tokenId].pbmType == PBMType.Frozen) return false;
        return true;
    }
}
