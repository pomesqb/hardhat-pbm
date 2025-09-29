// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./PBMWrapper.sol";
import "./StockSettlementLogic.sol";
import "./enums/PBMType.sol";

contract StockSettlementPBM is PBMWrapper {
    constructor(string memory _uriPostExpiry) PBMWrapper(_uriPostExpiry) {}

    event FrozenPBMRevoked(uint256 _frozenTokenId, uint256 storedRate);

    // 內部使用
    function _createAndMintPBM(
        string memory _tokenName,
        address _creator,
        address _recipient,
        uint256 _amount,
        uint256 _tokenExpiry,
        string memory _tokenURI
    ) internal returns (uint256) {
        uint256 newTokenId = IPBMTokenManager(pbmTokenManager).createTokenType(
            _tokenName,
            1,
            _tokenExpiry,
            _creator,
            _tokenURI,
            contractExpiry
        );
        _mint(_recipient, newTokenId, _amount, "");
        return newTokenId;
    }

    // 「買股票」流程使用
    function executeMintFromLogic(
        string memory _tokenName,
        address _fundingSource,
        address _recipient,
        uint256 _amount,
        uint256 _tokenExpiry,
        string memory _tokenURI
    ) external returns (uint256) {
        require(
            msg.sender == address(pbmLogic),
            "Only Logic contract can call"
        );

        ERC20Helper.safeTransferFrom(
            IERC20(spotToken),
            _fundingSource,
            address(this),
            _amount
        );

        return
            _createAndMintPBM(
                _tokenName,
                _recipient,
                _recipient,
                _amount,
                _tokenExpiry,
                _tokenURI
            );
    }

    //「賣股票」流程使用 (由集保呼叫)
    function createAndMintRemittancePBM(
        address _custodianRecipient,
        uint256 _amount,
        uint256 _settlementTimestamp
    ) external returns (uint256) {
        StockSettlementLogic logic = StockSettlementLogic(address(pbmLogic));
        require(
            msg.sender == logic.tdccAddress(),
            "Only TDCC can create remittance PBM"
        );
        ERC20Helper.safeTransferFrom(
            IERC20(spotToken),
            msg.sender,
            address(this),
            _amount
        );
        uint256 newTokenId = _createAndMintPBM(
            "Remittance PBM",
            msg.sender,
            _custodianRecipient,
            _amount,
            _settlementTimestamp + 365 days,
            ""
        );
        logic.registerRule(
            newTokenId,
            PBMType.Remittance,
            _settlementTimestamp,
            0
        );
        return newTokenId;
    }

    // 「凍結轉交割」流程使用 (由保管行呼叫)
    function convertFrozenToSettlement(
        uint256 _frozenTokenId,
        uint256 _amount,
        uint256 _settlementTimestamp
    ) external returns (uint256) {
        StockSettlementLogic logic = StockSettlementLogic(address(pbmLogic));
        require(
            logic.isCustodianBank(msg.sender),
            "Caller is not a custodian bank"
        );

        (
            PBMType pbmType,
            uint256 timeLockTimestamp,
            uint256 exchangeRate
        ) = logic.tokenRules(_frozenTokenId);
        require(pbmType == PBMType.Frozen, "Not a valid Frozen PBM");

        _burn(msg.sender, _frozenTokenId, _amount);

        uint256 newSettlementTokenId = _createAndMintPBM(
            "Settlement PBM",
            msg.sender,
            msg.sender,
            _amount,
            _settlementTimestamp + 365 days,
            ""
        );
        logic.registerRule(
            newSettlementTokenId,
            PBMType.Settlement,
            _settlementTimestamp,
            0
        );
        return newSettlementTokenId;
    }

    /**
     * @notice 撤銷一個已過期的「凍結PBM」，退還底層資金，並回傳當初的匯率
     * @dev 只有創建該 PBM 的保管行才能呼叫
     * @param _frozenTokenId 要撤銷的「凍結PBM」的 tokenId
     * @return exchangeRate 當初儲存的匯率
     */
    function revokeFrozenPBMAndGetRate(
        uint256 _frozenTokenId
    ) external whenNotPaused returns (uint256 exchangeRate) {
        // 獲取邏輯合約的實例
        StockSettlementLogic logic = StockSettlementLogic(address(pbmLogic));

        // 獲取此 tokenId 的創建者是誰
        (, , , , address creator) = IPBMTokenManager(pbmTokenManager)
            .getTokenDetails(_frozenTokenId);

        // --- 驗證 ---
        // 1. 身份驗證：呼叫者必須是保管行，且是這個 PBM 的創建者
        require(
            logic.isCustodianBank(msg.sender),
            "Caller is not a custodian bank"
        );
        require(msg.sender == creator, "Caller is not the creator of this PBM");

        // 2. 類型驗證：確認這是一個「凍結PBM」
        (PBMType pbmType, uint256 timeLockTimestamp, uint256 storedRate) = logic
            .tokenRules(_frozenTokenId);
        require(pbmType == PBMType.Frozen, "Not a valid Frozen PBM");

        // 3. 過期驗證：直接呼叫 PBMTokenManager 的 revokePBM 函式，它內部會檢查是否過期
        // 如果未過期，下方的交易會失敗
        IPBMTokenManager(pbmTokenManager).revokePBM(_frozenTokenId, msg.sender);

        // --- 執行撤銷與退款 ---
        // 計算總價值 (因為面額為1，所以數量即價值)
        uint256 valueOfTokens = balanceOf(msg.sender, _frozenTokenId);
        require(valueOfTokens > 0, "No frozen PBM to revoke");

        // 銷毀 PBM 代幣
        _burn(msg.sender, _frozenTokenId, valueOfTokens);

        // 將底層的數位新台幣退還給保管行
        ERC20Helper.safeTransfer(IERC20(spotToken), msg.sender, valueOfTokens);

        // 觸發事件
        emit FrozenPBMRevoked(_frozenTokenId, storedRate);

        // --- 回傳匯率 ---
        return storedRate;
    }
}
