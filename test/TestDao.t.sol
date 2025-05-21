// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Pluto} from "../src/GovToken.sol";
import {PlutocracyDao} from "../src/PlutocracyDao.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract TestDao is Test {
    MyGovernor governor;
    PlutocracyDao dao;
    TimeLock timelock;
    Pluto pluto;

    address public user = makeAddr("user");
    uint256 public constant initialBalance = 10 ether;
    uint256 public constant min_delay = 3600;
    uint256 public constant votingDelay = 7200;
    uint256 public constant votingPeriod = 50400;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() public {
        pluto = new Pluto();
        pluto.mint(user, initialBalance);
        pluto.delegate(user);

        vm.startPrank(user);
        pluto.delegate(user);
        timelock = new TimeLock(min_delay, proposers, executors, msg.sender);
        governor = new MyGovernor(pluto, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, user);

        vm.stopPrank();

        vm.startPrank(user);
        dao = new PlutocracyDao(user);
        dao.transferOwnership(address(timelock));
        vm.stopPrank();
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        dao.store(1);
    }

    function testGovernanceUpdatesDao() public {
        uint256 valueToStore = 888;
        string memory description = "Store 888 in the dao";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(dao));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + votingDelay);
        vm.roll(block.number + votingDelay + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        string memory reson = "Vote for proposal";

        uint8 voteWay = 1;

        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reson);

        vm.warp(block.timestamp + votingPeriod + 1);
        vm.roll(block.number + votingPeriod + 1);

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + min_delay + 1);
        vm.roll(block.number + min_delay + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        console.log("Proposal State: ", dao.getNumber());
        assert(dao.getNumber() == valueToStore);
    }
}
