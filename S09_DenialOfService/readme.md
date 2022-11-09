---
title: S09. DOS 攻击
tags:
  - solidity
  - security
---

# WTF Solidity 合约安全: S09. DOS 攻击

我最近在重新学 solidity，巩固一下细节，也写一个“WTF Solidity 极简入门”，供小白们使用（编程大佬可以另找教程），每周更新 1-3 讲。

推特：[@0xAA_Science](https://twitter.com/0xAA_Science)｜[@WTFAcademy\_](https://twitter.com/WTFAcademy_)

社区：[Discord](https://discord.wtf.academy)｜[微信群](https://docs.google.com/forms/d/e/1FAIpQLSe4KGT8Sh6sJ7hedQRuIYirOoZK_85miz3dw7vA1-YjodgJ-A/viewform?usp=sf_link)｜[官网 wtf.academy](https://wtf.academy)

所有代码和教程开源在 github: [github.com/AmazingAng/WTFSolidity](https://github.com/AmazingAng/WTFSolidity)

---

这一讲，我们将介绍 DOS 攻击（Denial of Service）。这是一种通过合约漏洞使合约服务不能使用的攻击类型。

## 无法预知的 revert 触发 DoS

考虑到下面这个简单的例子：
合约记录了当前最高出价人和最高出价的数额，并声明了核心的 `bid` 竞价函数，只有当传入的 `msg.value` 大于当前的最高出价才会更新最高出价与最高出价者，之后会退还上一个最高出价者的资金。

```solidity
// INSECURE
contract Auction {
    address currentLeader; // 当前最高出价者
    uint highestBid; // 最高出价

    function bid() public payable {
        require(msg.value > highestBid);

        require(currentLeader.send(highestBid)); // 退还资金给上一个出价者, 如果失败则 revert

        currentLeader = msg.sender;
        highestBid = msg.value;
    }
}
```

如果攻击者使用具有 `revert` 功能的智能合约出价，则攻击者可以永远保持自己是最高出价者。
当合约尝试给上一个最高出价者退款时，如果退款失败它会恢复成上一次的最高出价者。这意味着恶意竞标者可以永远成为最高出价者。通过这种方式，他们可以阻止其他人调用该 `bid()` 函数。

通常的防御办法是声明一个单独的转移资金函数，让用户主动调用。

```solidity
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
```

另一个例子是当一个合约可以迭代一个数组退款给用户（例如，众筹合约中的支持者）时。通常希望确保每次付款都成功。如果没有，应该 `revert`。问题是，如果一次交易失败，将 `revert` 整个支付系统，这意味着永远不会完成。因为一个地址导致错误，没有人得到报酬。

```solidity
address[] private refundAddresses;
mapping (address => uint) public refunds;

// bad
function refundAll() public {
    for(uint x; x < refundAddresses.length; x++) { // arbitrary length iteration based on how many addresses participated
        require(refundAddresses[x].send(refunds[refundAddresses[x]])) // doubly bad, now a single failure on send will hold up all funds
    }
}
```

同样，推荐的解决方案是 支持单独的退款操作。

## Gas limit 导致的 DOS 攻击

每个操作都有一个可供消耗的 gas 的上限。如果消耗的 gas 超过此限制，则交易将失败。这就导致了 DOS 攻击：

上一个示例的另一个问题：通过一次向所有人付款，很可能会遇到 gas limit。

即使在没有故意攻击的情况下，这也可能导致问题。但是，如果攻击者可以操纵所需的 gas，那就特别糟糕了。在前面的例子中，攻击者可以添加一堆地址，每个地址都需要得到非常小的退款。因此，退款每个攻击者地址的 gas 成本最终可能会超过 gas 限制，从而完全阻止退款交易的发生。

如果必须遍历一个未知大小的数组，最好能跟踪到当前的交易，知道还有多少交易没有完成，并能够从中继续，如以下示例所示：

```solidity
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
```

## 总结

这一讲，我们介绍了 DOS 攻击的两种情况：

- 在转账交易时，如果逻辑建立在转账成功的基础上，会有被恶意 revert 的漏洞出现。未知的有多种方法可以使智能合约无法工作。
- 在循环调用操作时需要注意，不要被恶意攻击从而超出 gas limit，最终导致交易的失败。
