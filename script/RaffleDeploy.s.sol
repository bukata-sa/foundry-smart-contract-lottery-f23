// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2} from "@chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

uint256 constant CHAINID_FOUNDRY = 31337;
uint256 constant CHAINID_ETHEREUM_SEPOLIA = 11155111;

contract RaffleDeployAnvil is Script {
    function run() external returns (Raffle) {
        if (block.chainid == CHAINID_FOUNDRY) {
            return this.deployDefault();
        }
        revert("Unknown chain");
    }

    function deployDefault() external returns (Raffle) {
        return this.deploy(0.001 ether, 60 * 10);
    }

    function deploy(uint256 entranceFee, uint256 raffleIntervalSec) external returns (Raffle) {
        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(0.0001 ether, 1 gwei);
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1e18);
        Raffle raffle = new Raffle(entranceFee, address(vrfCoordinator), subId, 0x0, raffleIntervalSec);
        vrfCoordinator.addConsumer(subId, address(raffle));
        vm.stopBroadcast();
        return raffle;
    }
}

contract RaffleDeploySepolia is Script {
    function run() external returns (Raffle) {
        if (block.chainid == CHAINID_ETHEREUM_SEPOLIA) {
            return this.deployDefault();
        }
        revert("Unknown chain");
    }

    function deployDefault() external returns (Raffle) {
        return this.deploy(0.001 ether, 60 * 10);
    }

    function deploy(uint256 entranceFee, uint256 raffleIntervalSec) external returns (Raffle) {
        vm.startBroadcast();
        LinkTokenInterface LINK = LinkTokenInterface(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        VRFCoordinatorV2 vrfCoordinator = VRFCoordinatorV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        uint64 subId = vrfCoordinator.createSubscription();
        LINK.transferAndCall(address(vrfCoordinator), 1 /*LINK*/ ether, abi.encode(subId));
        Raffle raffle = new Raffle({
            entranceFee: entranceFee,
            _vrfCoordinator: address(vrfCoordinator),
            _subscriptionId: subId,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            lotteryIntervalSec: raffleIntervalSec
        });
        vrfCoordinator.addConsumer(subId, address(raffle));
        vm.stopBroadcast();
        return raffle;
    }
}
