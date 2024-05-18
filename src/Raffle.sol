// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

enum State {
    INACTIVE,
    ACTIVE,
    FINALIZED
}

contract Raffle {
    error Raffle__LotteryNotAvailable();
    error Raffle__InvalidFee();

    event Raffle__EnteredRaffle(address participant, uint256 amount);

    State private s_state;

    address payable[] private s_players;

    uint256 private immutable i_entranceFee;

    constructor(uint256 entranceFee) {
        s_state = State.INACTIVE;
        i_entranceFee = entranceFee;
    }

    function buyTicket() public payable {
        if (s_state != State.ACTIVE) {
            revert Raffle__LotteryNotAvailable();
        }
        if (msg.value < i_entranceFee || msg.value % i_entranceFee != 0) {
            revert Raffle__InvalidFee();
        }
        uint256 amount = msg.value / i_entranceFee;
        for (uint256 i = 0; i < amount; i++) {
            s_players.push(payable(msg.sender));
        }
        emit Raffle__EnteredRaffle(msg.sender, amount);
    }

    function spinTheWheel() public {}
}
