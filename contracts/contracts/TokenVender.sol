// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "maci-contracts/sol/MACI.sol";

import "./FundingRoundFactory.sol";
import "./FundingRound.sol";

import "./userRegistry/IUserRegistry.sol";
import "./userRegistry/SimpleUserRegistry.sol";
import "./recipientRegistry/IRecipientRegistry.sol";

import "hardhat/console.sol";

contract TokenVender is ERC20, IUserRegistry, SimpleUserRegistry {
    using SafeERC20 for ERC20;

    // State
    uint256 public ubiAmount; // provide verified users with a certain number of free tokons for voting
    uint256 public constant tokensPerAssetToken = 1; // 一顆 asset token 可換取多少 voting token？

    ERC20 public assetToken;
    FundingRoundFactory public fundingRoundFactory;

    mapping(uint256 => bool) public tokensRedeemed;

    // Events
    event BuyTokens(address buyer, uint256 amountOfAssetTokens, uint256 amountOfTokens);
    event MatchingFundsAdded(address _sender, uint256 indexed _amount);
    event TokensRedeemed(uint256 indexed _voteOptionIndex, address indexed _recipient, uint256 _amount);

    constructor(
        FundingRoundFactory _fundingRoundFactory,
        ERC20 _assetToken,
        string memory name,
        string memory symbol,
        uint256 _ubiAmount
    ) public ERC20(name, symbol) SimpleUserRegistry() {
        fundingRoundFactory = _fundingRoundFactory;
        assetToken = _assetToken;
        ubiAmount = _ubiAmount;
    }

    /**
     * @dev Add verified unique user to the registry and mint tokens to the user
     */
    function addUser(address _user) external override onlyOwner {
        require(_user != address(0), "TokenVender: User address is zero");
        require(!users[_user], "TokenVender: User already verified");
        users[_user] = true;
        _mint(_user, ubiAmount);
        emit UserAdded(_user);
    }

    /**
     * @dev Buy voting tokens by asset tokens
     */
    function buyTokens(uint256 _amount) external {
        assetToken.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount * tokensPerAssetToken);
        emit BuyTokens(msg.sender, _amount, _amount * tokensPerAssetToken);
    }

    /**
     * @dev Redeem asset tokens according to allocation
     */
    function redeemTokens(FundingRound _fundingRound, uint256 _voteOptionIndex, uint256 _spent) external {
        MACI maci = _fundingRound.maci();

        (bool fundsClaimed,, uint256 tallyResult) = _fundingRound.recipients(_voteOptionIndex);

        // token should be claimed
        require(fundsClaimed, "TokenVender: Funds already claimed");

        // should not double redeem
        require(!tokensRedeemed[_voteOptionIndex], "TokenVender: Token already redeemed");
        tokensRedeemed[_voteOptionIndex] = true;

        // 使用 round.getAllocatedAmount 來驗證可換取 dai 的 token 數量
        uint256 allocatedAmount = _fundingRound.getAllocatedAmount(tallyResult, _spent);

        IRecipientRegistry recipientRegistry = _fundingRound.recipientRegistry();

        uint256 startTime = maci.signUpTimestamp();
        address recipient = recipientRegistry.getRecipientAddress(
            _voteOptionIndex, startTime, startTime + maci.signUpDurationSeconds() + maci.votingDurationSeconds()
        );

        require(msg.sender == recipient, "TokenVender: Sender is not the recipient");

        // main logic
        // allocatedAmount: unit of voting token

        _burn(msg.sender, allocatedAmount / tokensPerAssetToken);

        assetToken.safeTransfer(recipient, allocatedAmount / tokensPerAssetToken);

        emit TokensRedeemed(_voteOptionIndex, recipient, allocatedAmount / tokensPerAssetToken);
    }

    /**
     * @dev Add voting tokens to matching funds by asset tokens
     * issue: 這是為了方便使用者，可以不需要 buy tokens 再 transfer 到 factory
     * perf: 這樣使用者捐款到資金池所花費的 gas 會比直接送 DAI 到資金池還來得貴
     * solution 1: 可透過 geloto 偵測 dai 有無打入此合約，然後自動執行 mint token 到 factory
     */
    function addMatchingFunds(uint256 _amount) external {
        assetToken.safeTransferFrom(msg.sender, address(this), _amount);
        _mint(address(fundingRoundFactory), _amount / tokensPerAssetToken);
        emit MatchingFundsAdded(msg.sender, _amount);
    }
}
