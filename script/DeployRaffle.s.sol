// // SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {HandleSubscription} from "./Interactions.s.sol";
// import {FundSubscription} from "./Interactions.s.sol";
// import {AddConsumer} from "./Interactions.s.sol";



contract DeployRaffle is Script {
    uint256 constant ENTRANCE_FEE = 123;
    uint256 constant INTERVAL = 123;

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        HandleSubscription handleSubscription = new HandleSubscription();
        if (networkConfig.subscriptionId == 0) {  
            networkConfig.subscriptionId = handleSubscription.createSubscription(networkConfig.vrfCoordinator, networkConfig.account);
            handleSubscription.fundSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.subscriptionId,
                networkConfig.linkToken,
                networkConfig.account
            );
        }

        vm.startBroadcast(networkConfig.account);
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId
        );
        vm.stopBroadcast();
        console.log("Deployed Raffle Contract: ", address(raffle));

        handleSubscription.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.account);

        return (raffle, helperConfig);
    }

    function run() public {
        deployRaffle();
    }
}

