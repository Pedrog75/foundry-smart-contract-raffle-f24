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
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle contract
 * @author Pedro
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
  error Raffle_NotEhoughEthSent();
  error Raffle__TransferFailed();
  error Raffle__RaffleNotOpen();
  error Raffle__UpkeepNotNeeded(
    uint256 currentBalance,
    uint256 numPlayers,
    uint256 raffleState
    );

  /*Types declarations*/
  enum RaffleState {OPEN, CALCULATING}

  /** State Variables */
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;
  uint256 private immutable i_entranceFee;
  //@dev duration of the lottery in seconds
  uint256 private immutable i_interval;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  bytes32 private immutable i_gasLine;
  uint64 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;

  uint256 private s_lastTimeStamp;
  address payable[] private s_players;
  address private s_recentWinner;
  RaffleState private s_raffleState;

  event EnteredRaffle(address indexed player);
  event PickedWinner(address indexed winner);
  event RequestedRaffleWinner(uint256 indexed requestId);

  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinator,
    bytes32 gasLine,
    uint64 subscriptionId,
    uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator){
    i_entranceFee = entranceFee;
    i_interval = interval;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
    i_gasLine = gasLine;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_raffleState = RaffleState.OPEN;
    s_lastTimeStamp = block.timestamp;
  }

  function enterRaffle() external payable{
    // Enter the raffle
     if(msg.value < i_entranceFee){
      revert Raffle_NotEhoughEthSent();
    }
    if(s_raffleState != RaffleState.OPEN){
      revert Raffle__RaffleNotOpen();
    }
    s_players.push(payable(msg.sender));
    emit EnteredRaffle(msg.sender);
  }

  // When is the winner supposed to be picked?
  /**
   * @dev This function thaht the chainlink automation nodes call
   * to see if it's time to perfom an upkeep.
   * The following should be true for this to return true:
   * 1. The time interval has passed between raffle runs
   * 2. The raffle is in the OPEN state
   * 3. Contract has Eth (aka players )
   * 4. (Implicit) The subscription is funded with Link
   */
  function checkUpkeep(
    bytes memory /*checkData*/
    )public view returns (bool upkeepNeeded, bytes memory /*performData*/){
        //* 1. The time interval has passed between raffle runs
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        //* 2. The raffle is in the OPEN state
        bool isOpen = RaffleState.OPEN == s_raffleState;
        //* 3. Contract has Eth(aka players )
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }
  // 1. Get a random number
  // 2. Use the random number to pick a player
  // 3. Be automatically called
  function performUpkeep(bytes calldata /* perfomeData*/) external {
    (bool upkeepNeeded, ) = checkUpkeep("");
    if(!upkeepNeeded){
      revert Raffle__UpkeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
    }

    //Check if enough time has passed
    s_raffleState = RaffleState.CALCULATING;
    //Get a random number
    // 1. Ask the RNG
    // 2. Get the random number
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLine,//keyHash -> gas lane
            i_subscriptionId, //s_subscriptionId -> id funded with link
            REQUEST_CONFIRMATIONS, //requestConfirmations -> block needed to be a confirmed
            i_callbackGasLimit, //callbackGasLimit,
            NUM_WORDS //numWords
        );
    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(
    uint256 /*requestId*/,
    uint256[] memory randomWords
  ) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable winner = s_players[indexOfWinner];
    s_recentWinner = winner;
    s_raffleState = RaffleState.OPEN;

    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;

    (bool success, ) = winner.call{value: address(this).balance}("");
    if(!success){
      revert Raffle__TransferFailed();
    }

    emit PickedWinner(winner);

  }




  /** Getter function */
  function getEntranceFee() external view returns(uint256){
    return i_entranceFee;
  }

  function getRaffleState() public view returns(RaffleState){
    return s_raffleState;
  }

  function getPlayer(uint256 indexOfPlayer) external view returns(address){
    return s_players[indexOfPlayer];
  }

  function getRecentWinner() external view returns(address){
    return s_recentWinner;
  }

  function getLenghOfPlayers() external view returns(uint256){
    return s_players.length;
  }

  function getLastTimeStamp() external view returns(uint256){
    return s_lastTimeStamp;
  }
}
