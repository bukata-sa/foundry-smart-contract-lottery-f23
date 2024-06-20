// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

enum State {
    READY,
    RUNNING,
    CLOSED
}

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle__WrongState();
    error Raffle__InvalidFee();
    error Raffle__TransferError();
    error Raffle__UpkeepNotNeeded();

    event NewParticipant(address participant, uint256 amount);
    event WinnerSelected(address participant, uint256 prize);

    uint16 private constant NUM_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 100_000;
    uint32 private constant NUM_WORDS = 1;

    State private s_state;
    address payable[] private s_players;
    uint256 private s_lastVrfRequestId;
    uint256 private s_lastTimestampSec;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_entranceFee;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_lotteryIntervalSec;

    constructor(
        uint256 entranceFee,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 gasLane,
        uint256 lotteryIntervalSec
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        require(entranceFee > 0, "Entrance fee should be more than 0");
        s_state = State.READY;
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_subscriptionId = _subscriptionId;
        i_gasLane = gasLane;
        i_lotteryIntervalSec = lotteryIntervalSec;
    }

    function buyTicket() public payable returns (uint256) {
        if (s_state == State.CLOSED) {
            revert Raffle__WrongState();
        }
        if (msg.value < i_entranceFee || msg.value % i_entranceFee != 0) {
            revert Raffle__InvalidFee();
        }
        uint256 amount = msg.value / i_entranceFee;
        for (uint256 i = 0; i < amount; i++) {
            s_players.push(payable(msg.sender));
        }
        emit NewParticipant(msg.sender, amount);
        if (s_state == State.READY) {
            s_state = State.RUNNING;
            s_lastTimestampSec = block.timestamp;
        }
        return amount;
    }

    function checkUpkeep(bytes calldata /*checkData*/ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (isItTimeToSpinTheWheel(), "");
    }

    function isItTimeToSpinTheWheel() internal view returns (bool) {
        bool timeHasPassed = block.timestamp >= s_lastTimestampSec + i_lotteryIntervalSec;
        bool hasPlayers = s_players.length > 0;
        bool isRunning = s_state == State.RUNNING;
        return timeHasPassed && hasPlayers && isRunning;
    }

    function performUpkeep(bytes calldata /*performData*/ ) external override {
        if (isItTimeToSpinTheWheel()) {
            spinTheWheel();
        } else {
            revert Raffle__UpkeepNotNeeded();
        }
    }

    function spinTheWheel() private {
        s_state = State.CLOSED;
        s_lastVrfRequestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, NUM_CONFIRMATIONS, CALLBACK_GAS_LIMIT, NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        if (s_state != State.CLOSED || s_lastVrfRequestId == 0) {
            revert Raffle__WrongState();
        }
        if (s_lastVrfRequestId != requestId) {
            revert("Error");
        }
        uint256 num = s_players.length;
        uint256 winnerIndex = randomWords[0] % num;
        address payable winner = s_players[winnerIndex];
        uint256 prize = address(this).balance;
        require(prize == num * i_entranceFee, "wtf");
        s_players = new address payable[](0);
        s_state = State.READY;
        s_lastTimestampSec = block.timestamp;
        emit WinnerSelected(winner, prize);

        (bool success,) = winner.call{value: prize}("");
        if (!success) {
            revert Raffle__TransferError();
        }
    }

    function players() public view returns (address payable[] memory) {
        return s_players;
    }

    function state() public view returns (State) {
        return s_state;
    }

    function vrfCoordinator() public view returns (address) {
        return address(i_vrfCoordinator);
    }

    function lastVrfRequestId() public view returns (uint256) {
        return s_lastVrfRequestId;
    }

    function subscriptionId() public view returns (uint64) {
        return i_subscriptionId;
    }
}
