// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
//import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title Raffle contract
 * @author rohan
 * @notice This contract is a basic implementation of a raffle system.
 * @dev The contract implements Chainlink VRFv2.5 for secure random number generation.
 */
contract Raffle is VRFConsumerBaseV2 {
    //errors
    error Raffle__NotEnoughEthEntered();
    error Raffle__UpKeepNotTrueYet(uint256 raffleState, uint256 playerCount, uint256 timePassed);
    error Raffle__RaffleNotOpen();
    error Raffle__transferFailedToWinner();

    //types
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    // Chainlink VRF related variables
    address immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLaneKeyHash;
    uint256 private immutable i_subId;
    uint32 private immutable i_callbackGasLimit;

    // Raffle related variables
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_cycleDuration;

    address payable[] private s_playerArray;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;
    address private s_recentWinner;

    //events
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    //functions
    constructor(
        uint256 entranceFee,
        uint256 cycleDuration,
        address vrfCoordinator,
        bytes32 gasLaneKeyHash,
        uint256 subId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_cycleDuration = cycleDuration;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;

        i_vrfCoordinator = vrfCoordinator;
        i_gasLaneKeyHash = gasLaneKeyHash;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthEntered();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        address payable player = payable(msg.sender);
        s_playerArray.push(player);

        emit RaffleEnter(msg.sender);
    }

    //@dev Chainlink automations- this function is called by the Chainlink nodes continuously to check if upkeep is needed

    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasPlayers = (s_playerArray.length > 0);
        bool timePassed = (block.timestamp - s_lastTimeStamp >= i_cycleDuration);
        upkeepNeeded = (isOpen && hasPlayers && timePassed);

        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes memory) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotTrueYet(
                uint256(s_raffleState), s_playerArray.length, block.timestamp - s_lastTimeStamp
            );
        }

        s_raffleState = RaffleState.CALCULATING; //enough time has passed, raffle is calculating winner

        /*uint256 reqId = */
        uint256 requestId = VRFCoordinatorV2Interface(i_vrfCoordinator).requestRandomWords(
            i_gasLaneKeyHash,
            uint64(i_subId),
            3, // requestConfirmations
            i_callbackGasLimit,
            1 // numWords
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        if (s_playerArray.length == 0) return; // Guard against empty array

        uint256 winnerIndex = randomWords[0] % s_playerArray.length;
        address payable winner = s_playerArray[winnerIndex];

        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_playerArray = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = winner.call{value: address(this).balance}(""); //transfer the balance to the winner
        if (!success) {
            revert Raffle__transferFailedToWinner();
        }
        emit WinnerPicked(winner);
    }

    //getters
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_playerArray[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getCycleDuration() public view returns (uint256) {
        return i_cycleDuration;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_playerArray.length;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }
}
