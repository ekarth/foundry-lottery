// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol" ;

contract TestRaffle is Test, Script, CodeConstants {
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testRaffleInitialisesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenPayLessThanEntranceFee() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.expectRevert(Raffle.Raffle__InsufficientEthSentToEnterRaffle.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testRaffleUpdatesPlayersWhenEntered() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.expectEmit(false, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testNotAllowToEnterWhileRaffleIsCalculating() public {
        // arrange
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}(); // player enter raffle
        vm.warp(block.timestamp + interval + 5); // set block.timestanp for making sure enough time has passed to pick up the winner
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // act/assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseWhenNoBalance() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 5); // set block.timestanp for making sure enough time has passed to pick up the winner
        vm.roll(block.number + 1);
        vm.deal(address(raffle), 0);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseWhenNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseWhenRaffleNotOpen() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}(); // player enter raffle
        vm.warp(block.timestamp + interval + 5); // set block.timestanp for making sure enough time has passed to pick up the winner
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseWhenNotEnoughPlayers() public {
        vm.warp(block.timestamp + interval + 5); // set block.timestanp for making sure enough time has passed to pick up the winner
        vm.roll(block.number + 1);
        vm.deal(address(raffle), 1 ether);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testPerformUpkeepRunsOnlyWhenCheckUpkeepReturnsTrue() public raffleEnteredWithTimePassedMoreThanInterval {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepReturnsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = Raffle.RaffleState.OPEN;

        vm.expectRevert(abi.encodeWithSelector(
            Raffle.Raffle__UpkeepNotNeeded.selector,
            currentBalance,
            numPlayers,
            uint256(raffleState)
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredWithTimePassedMoreThanInterval {
        
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    modifier raffleEnteredWithTimePassedMoreThanInterval() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}(); // player enter raffle
        vm.warp(block.timestamp + interval + 5); // set block.timestanp for making sure enough time has passed to pick up the winner
        vm.roll(block.number + 1);
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 requestRandomId) public raffleEnteredWithTimePassedMoreThanInterval skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestRandomId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerAndSendsMoney() 
    public raffleEnteredWithTimePassedMoreThanInterval skipFork {
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i <= additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }


        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        vm.expectEmit(false, false, false, false);
        emit WinnerPicked(address(2));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        address recentWinner = raffle.getRecentWinner();

        

        assertEq(recentWinner.balance, STARTING_PLAYER_BALANCE + (additionalEntrants * entranceFee));
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assertEq(address(raffle).balance, 0);
        
    }
}
