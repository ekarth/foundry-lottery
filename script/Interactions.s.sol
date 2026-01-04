// // SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol" ;
import {HelperConfig} from "./HelperConfig.s.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; 
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract HandleSubscription is Script, CodeConstants {

    function createSubscriptionUsingConfig() public returns (uint256 subscriptionId){
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        if (networkConfig.subscriptionId != 0) {
            subscriptionId = createSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.account
            );
        }
    }

    function createSubscription(address vrfCoordinator, address account) public returns (uint256) {
        vm.startBroadcast(account);
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        (,,,address subOwner,) = VRFCoordinatorV2_5Mock(vrfCoordinator).getSubscription(subscriptionId);
        vm.stopBroadcast();
        console.log("Created SubscriptionId:", subscriptionId);
        console.log("Subscription owner: ", subOwner);
        return subscriptionId;
    }

    uint256 public constant FUND_AMOUNT = 3 ether;
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        address linkToken = networkConfig.linkToken;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, networkConfig.account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Funding Subscription: ", subscriptionId);
        console.log("On Network: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 1000);
            // LinkToken(linkToken).mint();
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }

    }

    function addConsumerUsingConfig(address mostRecentlyDeployedRaffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        addConsumer(mostRecentlyDeployedRaffleAddress, vrfCoordinator, subscriptionId, networkConfig.account);
    }

    function addConsumer(address consumerAddress, address vrfCoordinator, uint256 subscriptionId, address account) public {
        console.log("Adding consumer:", consumerAddress);
        console.log("For subscription id: ", subscriptionId);
        console.log("msg.sender for adding consumer: ", msg.sender);
        // vm.prank(msg.sender);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumerAddress);
        vm.stopBroadcast();
    }


    function run() public {
        createSubscriptionUsingConfig();
        fundSubscriptionUsingConfig();
        address mostRecentlyDeployedRaffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployedRaffleAddress);
    }
}

// contract FundSubscription is Script, CodeConstants {
    
//     uint256 public constant FUND_AMOUNT = 3 ether;
//     function fundSubscriptionUsingConfig() public {
//         HelperConfig helperConfig = new HelperConfig();
//         HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
//         address vrfCoordinator = networkConfig.vrfCoordinator;
//         uint256 subscriptionId = networkConfig.subscriptionId;
//         address linkToken = networkConfig.linkToken;
//         fundSubscription(vrfCoordinator, subscriptionId, linkToken);
//     }

//     function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
//         console.log("Funding Subscription: ", subscriptionId);
//         console.log("On Network: ", block.chainid);
//         if (block.chainid == LOCAL_CHAIN_ID) {
//             vm.startBroadcast();
//             VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 1000);
//             // LinkToken(linkToken).mint();
//             vm.stopBroadcast();
//         } else {
//             vm.startBroadcast();
//             LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
//             vm.stopBroadcast();
//         }
//     }

//     function run() public {
//         fundSubscriptionUsingConfig();
//     }
// }

// contract AddConsumer is Script 
// {
//     function addConsumerUsingConfig(address mostRecentlyDeployedRaffleAddress) public {
//         HelperConfig helperConfig = new HelperConfig();
//         HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
//         address vrfCoordinator = networkConfig.vrfCoordinator;
//         uint256 subscriptionId = networkConfig.subscriptionId;
//         addConsumer(mostRecentlyDeployedRaffleAddress, vrfCoordinator, subscriptionId);
//     }

//     function addConsumer(address consumerAddress, address vrfCoordinator, uint256 subscriptionId) public {
//         console.log("Adding consumer:", consumerAddress);
//         console.log("For subscription id: ", subscriptionId);
//         console.log("msg.sender for adding consumer: ", msg.sender);
//         // vm.prank(msg.sender);
//         vm.startBroadcast();
//         VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumerAddress);
//         vm.stopBroadcast();
//     }

//     function run() public {
//         address mostRecentlyDeployedRaffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
//         addConsumerUsingConfig(mostRecentlyDeployedRaffleAddress);
//     }
// }
