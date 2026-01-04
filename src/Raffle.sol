// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";



/**
 * @title Raffle contract
 * @author Killer
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // errors
    error Raffle__InsufficientEthSentToEnterRaffle();
    error Raffle__TransferFailed(address caller);
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 state);
    error Raffle__InvalidPlayerIndex(uint256 index);

    // data types
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // constants & immutables
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 50_000;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // @dev Duration of lottery in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;

    // storage variables
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint256 _subscriptionId
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_keyHash = _gasLane;
        i_subscriptionId = _subscriptionId;
        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < i_entranceFee) {
            revert Raffle__InsufficientEthSentToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool,
            bytes memory /* performData */
        )
    {
        bool enoughTimePassed = ((block.timestamp - s_lastTimestamp) >= i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        bool hasPlayers = (s_players.length > 0);
        if (enoughTimePassed && isOpen && hasBalance && hasPlayers) {
            return (true, "");
        }
        return (false, "");
    }

    function performUpkeep(
        bytes calldata /* performData */
    )
    external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 winPlayerIndex = s_players.length;
        address payable recentWinner = s_players[randomWords[0] % winPlayerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed(recentWinner);
        }
        emit WinnerPicked(recentWinner);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 i) external view returns(address) {
        if(i >= s_players.length) {
            revert Raffle__InvalidPlayerIndex(i);
        }
        return s_players[i];
    }

    function getRaffleState() public view returns(RaffleState) {
        return s_raffleState;
    }

    function getLastTimestamp() public view returns(uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() public view returns(address) {
        return s_recentWinner;
    }

}

// Type Declarations
// State Variables
// Events
// Modifiers
// Functions
// constructor
// receive
// fallback
// external
// public
// internal
// private
// view & pure functions
