// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFT} from "./NFT.sol";
import {RewardToken} from "./RewardToken.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
 * @title StakeNFT
 * @author Farman
 */

contract StakeNFT is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721Holder,
    ReentrancyGuard
{
    // STATE VARIABLES
    RewardToken private rewardToken;
    NFT private nft;

    uint256 private unbondingPeriod;
    uint256 private rewardDelayPeriod;
    uint256 private rewardRate;

    struct StakedNFT {
        address owner;
        uint256 startingBlocktime;
        uint256 startUnbondingBlocktime;
        uint256 lastRewardClaimBlocktime;
    }

    /**
     * @notice userStakedNFTs - Mapping from user address to array of token IDs that are staked by the user.
     * @notice stakedNFTDetails - Mapping from token(NFT) ID to details of the staked NFT.
     */
    mapping(address user => uint256[] tokenIds) private userStakedNFTs;
    mapping(uint256 tokenId => StakedNFT tokenDetails) public stakedNFTDetails; // making it public here for testing purposes.

    // EVENTS
    event NFTStaked(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event UnstakeNFT(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event WithdrawNFT(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event ClaimReward(address indexed user, uint256 amount, uint256 timestamp);

    // MODIFIERS
    modifier isTokenOwner(uint256 tokenId) {
        require(stakedNFTDetails[tokenId].owner == msg.sender, "You are not Owning this nft");
        _;
    }

    // CONSTRUCTOR
    constructor() {
        _disableInitializers();
    }

    // EXTERNAL FUNCTIONS

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _token The address of the reward token.
     * @param _nft The address of the NFT contract.
     * @param _unbondingPeriod The period after which the NFT can be withdrawn.
     * @param _rewardDelayPeriod The delay period for claiming rewards.
     * @param _rewardRate The rate at which rewards are calculated.
     */
    function initialize(
        address _token,
        address _nft,
        uint256 _unbondingPeriod,
        uint256 _rewardDelayPeriod,
        uint256 _rewardRate
    ) external initializer {
        __Ownable_init(msg.sender);
        nft = NFT(_nft);
        rewardToken = RewardToken(_token);
        unbondingPeriod = _unbondingPeriod;
        rewardDelayPeriod = _rewardDelayPeriod;
        rewardRate = _rewardRate;
    }

    /**
     * @notice Allows users to stake their NFTs.
     * @param tokenId The ID of the NFT to be staked.
     */
    function stakeNFT(uint256 tokenId) external whenNotPaused {
        require(nft.ownerOf(tokenId) == msg.sender, "You are not Owning this nft");
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        userStakedNFTs[msg.sender].push(tokenId);
        stakedNFTDetails[tokenId] = StakedNFT({
            owner: msg.sender,
            startingBlocktime: block.timestamp,
            startUnbondingBlocktime: 0,
            lastRewardClaimBlocktime: block.timestamp
        });
        emit NFTStaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Allows users to start the unbonding process for their staked NFTs.
     * @param tokenId The ID of the NFT to be unstaked.
     */
    function unstakeNFT(uint256 tokenId) external whenNotPaused isTokenOwner(tokenId) {
        StakedNFT storage stakeTokenInfo = stakedNFTDetails[tokenId];
        require(stakeTokenInfo.startUnbondingBlocktime == 0, "unbonding already initiated");
        stakeTokenInfo.startUnbondingBlocktime = block.timestamp;

        emit UnstakeNFT(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Allows users to withdraw their NFTs after the unbonding period.
     * @param tokenId The ID of the NFT to be withdrawn.
     */
    function withdrawNFT(uint256 tokenId) external whenNotPaused isTokenOwner(tokenId) nonReentrant {
        StakedNFT memory stakeTokenInfo = stakedNFTDetails[tokenId];
        require(
            block.timestamp >= (stakeTokenInfo.startUnbondingBlocktime + unbondingPeriod),
            "UnbondingPeriod not yet passed"
        );
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        _removeStakedToken(msg.sender, tokenId);
        delete stakedNFTDetails[tokenId];

        emit WithdrawNFT(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @notice Allows users to claim rewards for their staked NFTs.
     * @notice Real-time minting directly to the user's address.
     * @param tokenId The ID of the NFT for which rewards are to be claimed.
     */
    function claimReward(uint256 tokenId) external whenNotPaused isTokenOwner(tokenId) nonReentrant {
        StakedNFT storage stakeTokenInfo = stakedNFTDetails[tokenId];
        require(stakeTokenInfo.startUnbondingBlocktime == 0, "can't claim reward as Nft Unstaked");
        require(
            block.timestamp >= (stakeTokenInfo.lastRewardClaimBlocktime + rewardDelayPeriod),
            "Reward delay time not yet passed"
        );

        uint256 rewardTokenAmount = _calculateReward(tokenId);

        rewardToken.mint(stakeTokenInfo.owner, rewardTokenAmount * 1e18);
        stakeTokenInfo.lastRewardClaimBlocktime = block.timestamp;

        emit ClaimReward(msg.sender, rewardTokenAmount, block.timestamp);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    function setUnbondingPeriod(uint256 _unbondingPeriod) external onlyOwner {
        unbondingPeriod = _unbondingPeriod;
    }

    function setRewardDelayPeriod(uint256 _rewardDelayPeriod) external onlyOwner {
        rewardDelayPeriod = _rewardDelayPeriod;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unPause() external onlyOwner {
        _unpause();
    }

    // INTERNAL FUNCTIONS

    /**
     * @notice Removes a staked NFT from the user's list of staked NFTs.
     * @param user The address of the user.
     * @param tokenId The ID of the NFT to be removed.
     */
    function _removeStakedToken(address user, uint256 tokenId) internal {
        uint256 length = userStakedNFTs[user].length;
        for (uint256 i = 0; i < length; i++) {
            if (userStakedNFTs[user][i] == tokenId) {
                userStakedNFTs[user][i] = userStakedNFTs[user][length - 1];
                userStakedNFTs[user].pop();
                break;
            }
        }
    }

    /**
     * @notice Calculates the rewards for a staked NFT.
     * @param tokenId The ID of the NFT for which rewards are to be calculated.
     * @return The amount of reward tokens.
     */
    function _calculateReward(uint256 tokenId) internal view returns (uint256) {
        StakedNFT memory stakeTokenInfo = stakedNFTDetails[tokenId];
        uint256 stakedblocks = block.timestamp - stakeTokenInfo.lastRewardClaimBlocktime;
        require(stakedblocks > 0, "No time has passed since last claim");
        return stakedblocks * rewardRate;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
