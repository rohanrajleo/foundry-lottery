//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperconfig = new HelperConfig();
        HelperConfig.NetworkConfig memory netConfig = helperconfig.getConfig();

        if (netConfig.subId == 0) {
            //create a subscription if it doesn't exist
            CreateSubscription createSub = new CreateSubscription();
            (netConfig.subId, netConfig.vrfCoordinator) =
                createSub.createSubscription(netConfig.vrfCoordinator, netConfig.account);

            // UPDATE: Store the new subId in HelperConfig
            //helperconfig.setSubId(netConfig.subId); --> u do not need to do this, it is already done

            // fund it
            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(netConfig.vrfCoordinator, netConfig.subId, netConfig.link, netConfig.account);
        }

        vm.startBroadcast(netConfig.account);
        Raffle raffle = new Raffle(
            netConfig.entranceFee,
            netConfig.cycleDuration,
            netConfig.vrfCoordinator,
            netConfig.gasLaneKeyHash,
            netConfig.subId,
            netConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), netConfig.vrfCoordinator, netConfig.subId, netConfig.account);

        //temp
        console.log("chain id:", block.chainid);
        console.log("vrfCoordinator:", netConfig.vrfCoordinator);
        console.log("subId:", netConfig.subId);
        console.log("callbackGasLimit:", netConfig.callbackGasLimit);

        return (raffle, helperconfig);
    }
}
