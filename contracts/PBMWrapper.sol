// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IPBMRC1.sol";
import "./interfaces/IPBMTokenManager.sol";
import "./PBMLogic.sol";
import "./PBMTokenManager.sol";

library ERC20Helper {
    using SafeERC20 for IERC20;

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        SafeERC20.safeTransferFrom(token, from, to, value);
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        SafeERC20.safeTransfer(token, to, value);
    }
}

abstract contract PBMWrapper is ERC1155, Ownable, Pausable, IPBMRC1 {
    address public spotToken;
    address public pbmTokenManager;
    bool public initialised;
    uint256 public contractExpiry;
    PBMLogic public pbmLogic;

    constructor(string memory _uriPostExpiry) ERC1155("") Ownable(msg.sender) {
        pbmTokenManager = address(new PBMTokenManager(_uriPostExpiry));
    }

    function initialise(
        address _spotToken,
        uint256 _expiry,
        address _pbmLogic
    ) external virtual onlyOwner {
        require(!initialised, "PBM: Contract already initialised");
        require(
            _spotToken != address(0) && _pbmLogic != address(0),
            "PBM: Invalid addresses"
        );
        require(
            _expiry == 0 || _expiry > block.timestamp,
            "PBM: Invalid expiry"
        );
        spotToken = _spotToken;
        contractExpiry = _expiry;
        pbmLogic = PBMLogic(_pbmLogic);
        initialised = true;
    }

    modifier whenInitialised() {
        require(initialised, "PBM: Contract not initialised");
        _;
    }

    function serialise(uint256 num) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = num;
        return arr;
    }

    function uri(
        uint256 tokenId
    ) public view virtual override(ERC1155, IPBMRC1) returns (string memory) {
        return IPBMTokenManager(pbmTokenManager).uri(tokenId);
    }

    function owner()
        public
        view
        virtual
        override(Ownable, IPBMRC1)
        returns (address)
    {
        return super.owner();
    }

    function transferOwnership(
        address newOwner
    ) public virtual override(Ownable, IPBMRC1) onlyOwner {
        super.transferOwnership(newOwner);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override(ERC1155, IPBMRC1) whenNotPaused {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner nor approved"
        );
        require(
            pbmLogic.transferPreCheck(from, to, id),
            "PBM Logic: transfer preCheck not satisfied."
        );

        if (pbmLogic.unwrapPreCheck(to, id, data)) {
            uint256 valueOfTokens = amount *
                (IPBMTokenManager(pbmTokenManager).getTokenValue(id));
            _burn(from, id, amount);
            IPBMTokenManager(pbmTokenManager).decreaseBalanceSupply(
                serialise(id),
                serialise(amount)
            );
            ERC20Helper.safeTransfer(IERC20(spotToken), to, valueOfTokens);
            emit MerchantPayment(
                from,
                to,
                serialise(id),
                serialise(amount),
                spotToken,
                valueOfTokens
            );
        } else {
            _safeTransferFrom(from, to, id, amount, abi.encodePacked(data));
        }
    }

    function revokePBM(uint256 tokenId) public virtual override whenNotPaused {
        uint256 valueOfTokens = IPBMTokenManager(pbmTokenManager)
            .getPBMRevokeValue(tokenId);
        IPBMTokenManager(pbmTokenManager).revokePBM(tokenId, msg.sender);
        ERC20Helper.safeTransfer(IERC20(spotToken), msg.sender, valueOfTokens);
        emit PBMrevokeWithdraw(msg.sender, tokenId, spotToken, valueOfTokens);
    }
}
