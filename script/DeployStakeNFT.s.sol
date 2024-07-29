// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {StakeNFT} from "../src/StakeNFT.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {NFT} from "../src/NFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployStakeNFT is Script {
    /**
     * @notice Runs the deployment script and returns the addresses of the deployed contracts.
     * @return proxy The address of the deployed StakeNFT proxy contract.
     * @return nft The address of the deployed NFT contract.
     * @return rewardToken The address of the deployed RewardToken contract.
     */
    function run() external returns (address, address, address) {
        (address proxy, address nft, address rewardToken) = deployStakeNFT();
        return (proxy, nft, rewardToken);
    }

    /**
     * @notice Deploys the StakeNFT, NFT, and RewardToken contracts.
     */
    function deployStakeNFT() public returns (address, address, address) {
        RewardToken rewardToken = new RewardToken();
        NFT nft = new NFT();
        StakeNFT stakeNFT = new StakeNFT();

        uint256 unbondingPeriod = 100;
        uint256 rewardDelayPeriod = 50;
        uint256 rewardRate = 1; // 1 token per sec

        bytes memory data = abi.encodeWithSelector(
            stakeNFT.initialize.selector,
            address(rewardToken),
            address(nft),
            unbondingPeriod,
            rewardDelayPeriod,
            rewardRate
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(stakeNFT), data);

        //  Transfer ownership of the RewardToken to the StakeNFT contract
        rewardToken.transferOwnership(address(proxy));
        return (address(proxy), address(nft), address(rewardToken));
    }
}
