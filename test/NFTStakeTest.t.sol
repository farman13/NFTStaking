// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployStakeNFT} from "../script/DeployStakeNFT.s.sol";
import {StakeNFT} from "../src/StakeNFT.sol";
import {NFT} from "../src/NFT.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract NFTStakeTest is Test {
    DeployStakeNFT deploy;

    address public proxy;
    address nft;
    address rewardToken;
    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");

    // Setting up the initial state for the test, including deploying contracts and minting an NFT to USER address & giving approval to proxy contract.
    function setUp() external {
        deploy = new DeployStakeNFT();
        (proxy, nft, rewardToken) = deploy.run();

        vm.startPrank(address(deploy));
        NFT(nft).safeMint(
            USER,
            "https://lime-tricky-cephalopod-329.mypinata.cloud/ipfs/QmcmSKB8oSXNbjjDzEYwmHBXjPRm6ZbBPZA1i2Uep6VNaF"
        );
        vm.stopPrank();
        vm.prank(USER);
        NFT(nft).approve(address(proxy), 0);
    }

    // Modifier to stake an NFT before executing the rest of the function
    modifier EnsureStaked() {
        uint256 tokenId = 0;
        vm.prank(USER);
        StakeNFT(proxy).stakeNFT(tokenId);
        _;
    }

    // Tests that the owner of the NFT is correctly set
    function testowner() public view {
        address owner = NFT(nft).ownerOf(0);
        assertEq(USER, owner);
    }

    // Test modifier isTokenOwner
    function testIsTokenOwner() public {
        uint256 tokenId = 1;
        vm.prank(USER);
        vm.expectRevert(bytes("You are not Owning this nft"));
        StakeNFT(proxy).unstakeNFT(tokenId);
    }

    // Tests the staking functionality of the contract
    function testStakeNFT() public {
        uint256 tokenId = 0;
        vm.prank(USER);
        StakeNFT(proxy).stakeNFT(tokenId);
        address expectedOwner = NFT(nft).ownerOf(tokenId);
        address actualOwner = address(proxy);
        assertEq(expectedOwner, actualOwner);
    }

    // Tests the unstaking functionality of the contract by checking that unbonding Time is start or not
    function testunstakeNFT() public EnsureStaked {
        uint256 tokenId = 0;
        vm.prank(USER);
        StakeNFT(proxy).unstakeNFT(tokenId);

        (,, uint256 startUnbondingBlocktime,) = StakeNFT(proxy).stakedNFTDetails(tokenId);
        assertNotEq(startUnbondingBlocktime, 0);
    }

    // Tests that withdrawing an NFT before the unbonding period has passed fails
    function testWithdrawNFT() public EnsureStaked {
        uint256 tokenId = 0;
        vm.startPrank(USER);
        StakeNFT(proxy).unstakeNFT(tokenId);

        vm.expectRevert(bytes("UnbondingPeriod not yet passed"));
        StakeNFT(proxy).withdrawNFT(tokenId);

        vm.stopPrank();
    }

    //Tests the successful withdrawal of an NFT after the unbonding period has passed
    function testWithdrawNFTTransferNFT() public EnsureStaked {
        uint256 tokenId = 0;
        vm.startPrank(USER);
        StakeNFT(proxy).unstakeNFT(tokenId);

        vm.warp(block.timestamp + 101 seconds);
        StakeNFT(proxy).withdrawNFT(tokenId);
        address expectedOwner = NFT(nft).ownerOf(tokenId);
        address actualOwner = USER;
        assertEq(expectedOwner, actualOwner);
    }

    // Tests the reward claiming functionality of the contract by checking the balance of USER
    function testClaimReward() public EnsureStaked {
        uint256 tokenId = 0;
        vm.prank(USER);
        vm.warp(block.timestamp + 100 seconds);
        StakeNFT(proxy).claimReward(tokenId);

        assertNotEq(RewardToken(rewardToken).balanceOf(USER), 0);
    }

    // Tests that the contract can be paused and that staking is disabled while paused
    function testPause() public {
        vm.prank(address(deploy));
        StakeNFT(proxy).pause();

        vm.prank(USER);
        vm.expectRevert();
        StakeNFT(proxy).stakeNFT(0);
    }
}
