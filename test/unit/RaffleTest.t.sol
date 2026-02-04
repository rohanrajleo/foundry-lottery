//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";


contract RaffleTest is Test {
    Raffle private raffle;
    HelperConfig private helperConfig;

    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);


    address private fake_player = makeAddr("player");
    uint256 private constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 private constant ENTRANCE_FEE = 0.01 ether;

    uint256 entranceFee;
    uint256 cycleDuration;
    address vrfCoordinator;
    bytes32 gasLaneKeyHash;
    uint256 subId;
    uint32 callbackGasLimit;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        cycleDuration = config.cycleDuration;
        vrfCoordinator = config.vrfCoordinator;
        gasLaneKeyHash = config.gasLaneKeyHash;
        subId = config.subId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(fake_player, STARTING_PLAYER_BALANCE);
        
}

    function testRaffleInitiallyOpen() external view {
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(raffleState) == uint256(Raffle.RaffleState.OPEN));
    }

    function testRevertIfNotEnoughEthEntered() external {
        vm.expectRevert(Raffle.Raffle__NotEnoughEthEntered.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testplayerGettingAddedToArray() external {
        vm.startPrank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.stopPrank();

        address player = raffle.getPlayer(0);
        assertEq(raffle.getNumberOfPlayers(), 1);
        assertEq(player, fake_player);
    }

    function testEnterRaffleEmitsEvent() external {
        // First, expect the event before calling the function
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(address(this)); // because address(this) will call the function
        // Now call the function that emits the event
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function testNoEntryWhileRaffleCalculating() external{
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        // Simulate the raffle being in a calculating state
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        
    }

    function testCheckUpkeepReturnsFalseNoPlayer() external {
        // Simulate the raffle being in a calculating state
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        (bool upkeep,) = raffle.checkUpkeep("");
        assert(!upkeep);
    }

    function testCheckUpkeepReturnsFalseNotEnoughTimePassed() external {
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        (bool upkeep,) = raffle.checkUpkeep("");
        assert(!upkeep);
    }

    function testCheckUpkeepReturnsFalseRaffleNotOpen() external {
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeep,) = raffle.checkUpkeep("");
        assert(!upkeep);
    }

    function testCheckUpkeepReturnsTrue() external {
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        (bool upkeep,) = raffle.checkUpkeep("");
        assert(upkeep);
    }

    //ADD MORE TESTS 

    function testPerformUpkeepRunsOnlyIfCheckUpkeepTrue() external {
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);

       
        raffle.performUpkeep(""); 
    }

    function testPerformUpkeepRevertsIfCheckUpkeepFalse() external {
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotTrueYet.selector, rState, numPlayers,block.timestamp - raffle.getLastTimeStamp())
        );
        raffle.performUpkeep("");
   
    }

    // DO THIS SHIT LATER

    function testPerformUpkeepUpdatesRaffleStateAndEmitsWinnerPicked() external {
      vm.prank(fake_player);        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration + 1);
         vm.roll(block.number + 1);

      // Act
        vm.recordLogs();
         raffle.performUpkeep(""); // emits requestId
         Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
                assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
         }


    //Fuzz tests
    // function testFulfilRandomWordsRunAfterPerformUpkeep () external {
    //      vm.prank(fake_player);
    //     raffle.enterRaffle{value: ENTRANCE_FEE}();
    //     vm.warp(block.timestamp + cycleDuration +1);
    //     vm.roll(block.number + 1);
    //     vm.expectRevert();
    //     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));


    // }


    modifier skipForkTests() {
        if (block.chainid != 31337) {
            return ; // Skip the test if not on a local fork
        }
        _;
    }

    //-. stateless fuzz test for the above test
    function testFulfilRandomWordsRunAfterPerformUpkeepStateless (uint256 requestId) external skipForkTests{
        // Skip requestId = 1 (which is what the real test uses)
    vm.assume(requestId != 1);  
        
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        vm.expectRevert();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }


    function testFulfillRandomWordsPicksWinnerResetsArrayAndSendsMoney() external skipForkTests{
        vm.prank(fake_player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + cycleDuration +1);
        vm.roll(block.number + 1);
        

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }
        address expectedWinner = address(1);

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;
        
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = ENTRANCE_FEE * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }



}
