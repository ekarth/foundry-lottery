// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

error HelperConfig__InvalidChainId(uint256 chainId);

abstract contract CodeConstants {
    // Mock VRFCoordinator Values
    uint96 public constant BASE_FEE = 0.25 ether;
    uint96 public constant GAS_PRICE = 1e9;
    int256 public constant WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address linkToken;
        address account;
    }
    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigByChainId;

    constructor() {
        networkConfigByChainId[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigByChainId[chainId].vrfCoordinator != address(0)) {
            return networkConfigByChainId[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return createOrGetAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 6855961848112964525652693000940187621627970198934121374611388422603532609716,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xE2C38cBDe9CCA20e292D6F3D4Bd50e06DFbC22Ca
        });
    }

    function createOrGetAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vRFCoordinatorV2_5Mock =
            new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE, WEI_PER_UNIT_LINK);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: address(vRFCoordinatorV2_5Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500_000,
            subscriptionId: 0,
            linkToken: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
