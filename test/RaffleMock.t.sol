// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    RaffleDeployAnvil,
    RaffleDeploySepolia,
    CHAINID_FOUNDRY,
    CHAINID_ETHEREUM_SEPOLIA
} from "../script/RaffleDeploy.s.sol";
import {Raffle, State} from "../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleMockTest is Test {
    uint256 private constant ENTRANCE_FEE = 0.007 ether;
    uint256 private constant RAFFLE_INTERVAL = 60 * 10;

    address private immutable user = makeAddr("player");

    Raffle private raffle;

    function setUp() public {
        if (block.chainid == CHAINID_FOUNDRY) {
            RaffleDeployAnvil deploy = new RaffleDeployAnvil();
            raffle = deploy.deploy(ENTRANCE_FEE, RAFFLE_INTERVAL);
        } else if (block.chainid == CHAINID_ETHEREUM_SEPOLIA) {
            RaffleDeploySepolia deploy = new RaffleDeploySepolia();
            raffle = deploy.deploy(ENTRANCE_FEE, RAFFLE_INTERVAL);
        }
    }

    function testBuy10Tickets() public {
        uint16 ticketAmount = 10;
        vm.expectEmit(false, false, false, false, address(raffle));
        emit Raffle.NewParticipant(user, ticketAmount);

        assert(raffle.state() == State.READY);
        vm.deal(user, ENTRANCE_FEE * ticketAmount);
        vm.prank(user);
        uint256 amount = raffle.buyTicket{value: user.balance}();

        assertEq(ticketAmount, amount);
        assertEq(raffle.players()[0], payable(user));
        assertEq(address(raffle).balance, ENTRANCE_FEE * ticketAmount);
        assert(raffle.state() == State.RUNNING);
    }

    function testUpkeepNeededOnlyAfterInterval() public {
        testBuy10Tickets();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(false, upkeepNeeded);

        vm.warp(block.timestamp + RAFFLE_INTERVAL + 1);
        (upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(true, upkeepNeeded);
    }

    function testRevertIfUpkeepIsNotNeeded() public {
        vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    modifier raffleReady() {
        uint16 ticketAmount = 10;
        vm.deal(user, ENTRANCE_FEE * ticketAmount);
        vm.prank(user);
        uint256 amount = raffle.buyTicket{value: user.balance}();
        vm.warp(block.timestamp + RAFFLE_INTERVAL + 1);
        _;
    }

    modifier skipFork() {
        vm.skip(block.chainid != CHAINID_FOUNDRY);
        _;
    }

    function testPerformUpkeep() public raffleReady skipFork {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 subId = uint256(logs[0].topics[2]);
        assertEq(subId, raffle.subscriptionId());
    }

    function testSelectWinner() public raffleReady skipFork {
        raffle.performUpkeep("");
        VRFCoordinatorV2Mock vrfCoordinator = VRFCoordinatorV2Mock(raffle.vrfCoordinator());

        vm.expectEmit(false, false, false, false, address(raffle));
        emit Raffle.WinnerSelected(user, ENTRANCE_FEE * 10);
        vm.expectCall(user, ENTRANCE_FEE * 10, "");
        vrfCoordinator.fulfillRandomWords(raffle.lastVrfRequestId(), address(raffle));

        assertEq(address(raffle).balance, 0);
        assertEq(address(user).balance, ENTRANCE_FEE * 10);
        assert(raffle.state() == State.READY);
        assert(raffle.players().length == 0);
    }
}
