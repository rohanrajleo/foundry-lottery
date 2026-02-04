//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    //VRF mock values
    uint96 public constant MOCK_BASE_FEE = 0.25 ether; // 0.25 LINK per request
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9; // 0.000000001 LINK per gas
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__invalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 cycleDuration;
        address vrfCoordinator;
        bytes32 gasLaneKeyHash;
        uint64 subId;
        uint32 callbackGasLimit;
        address link; // Only used for Sepolia, not needed for Anvil
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigMapping;

    constructor() {
        networkConfigMapping[11155111] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigMapping[chainId].vrfCoordinator != address(0)) {
            return networkConfigMapping[chainId];
        } else if (chainId == 31337) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__invalidChainId();
        }
    }

    function getConfig() external returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            //DID NOT VERIFY THE VRF ANF KEY HASH ADDR
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLaneKeyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 0, ///////
            callbackGasLimit: 100000,
            entranceFee: 0.01 ether,
            cycleDuration: 60,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x5B6732937877542BD82363385f0D57A8D46461e6 //acc1
        });
    }

    function setSubId(uint64 newSubId) external {
        if (block.chainid == 31337) {
            localNetworkConfig.subId = newSubId;
        } else {
            networkConfigMapping[block.chainid].subId = newSubId;
        }
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mock
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK);
        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            vrfCoordinator: address(vrfCoordinator),
            gasLaneKeyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, //does not matter, mock will work fine
            subId: 0, ///////////
            callbackGasLimit: 100000, //same here
            entranceFee: 0.01 ether,
            cycleDuration: 60,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 // foundry default sender from base.sol
        });

        return localNetworkConfig;
    }
}
