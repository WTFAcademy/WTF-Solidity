// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Auction {
    address currentLeader; // 当前最高出价者
    uint256 highestBid; // 最高出价
    mapping(address => uint256) public balance; // 储存每个出价者的地址金额映射

    function bid() public payable {
        require(msg.value > highestBid);
        balance[currentLeader] = highestBid;
        currentLeader = msg.sender;
        highestBid = msg.value;
    }

    // 转移资金
    function withdraw() public {
        require(msg.sender != currentLeader);
        require(balance[msg.sender] != 0);
        payable(msg.sender).transfer(balance[msg.sender]);
        balance[msg.sender] = 0;
    }
}

contract GasLimitResolve {
    struct Payee {
        address addr;
        uint256 value;
    }

    Payee[] payees;
    uint256 nextPayeeIndex;

    function payOut() public {
        uint256 i = nextPayeeIndex;
        while (i < payees.length && gasleft() > 200000) {
            payable(payees[i].addr).transfer(payees[i].value);
            i++;
        }
        nextPayeeIndex = i;
    }
}
