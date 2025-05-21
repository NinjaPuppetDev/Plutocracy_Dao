// SPDX-License-Identifier: MIT

// Contract controlled by a dao
// Every transaction that the DAO wants to send has to be voted on
// We will use ERC20 tokens for voting (Bad model, )
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PlutocracyDao is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 newNumber);

    constructor(address initialOwner) Ownable(initialOwner) {
        s_number = 0;
    }

    function store(uint256 newNumber) public onlyOwner {
        s_number = newNumber;
        emit NumberChanged(newNumber);
    }

    function getNumber() external view returns (uint256) {
        return s_number;
    }
}
