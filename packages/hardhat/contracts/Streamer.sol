// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Streamer is Ownable {
    event Opened(address, uint256);
    event Challenged(address);
    event Withdrawn(address, uint256);
    event Closed(address);

    mapping(address => uint256) balances;
    mapping(address => uint256) canCloseAt;

    struct Voucher {
        uint256 updatedBalance;
        Signature sig;
    }
    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    function fundChannel() public payable {
        require(msg.value > 0, "Please Provide Funds!");
        require(balances[msg.sender] == 0, "You already opened a channel");
        balances[msg.sender] = msg.value;
        emit Opened(msg.sender, msg.value);
    }

    function timeLeft(address channel) public view returns (uint256) {
        require(canCloseAt[channel] != 0, "channel is not closing");
        if (canCloseAt[channel] < block.timestamp) {
            return 0;
        } else {
            return canCloseAt[channel] - block.timestamp;
        }
    }

    function withdrawEarnings(Voucher calldata voucher) public onlyOwner {
        bytes32 hashed = keccak256(abi.encode(voucher.updatedBalance));

        bytes memory prefixed = abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            hashed
        );
        bytes32 prefixedHashed = keccak256(prefixed);

        address _msgSender = ecrecover(
            prefixedHashed,
            voucher.sig.v,
            voucher.sig.r,
            voucher.sig.s
        );
        require(
            balances[_msgSender] > voucher.updatedBalance,
            "Insufficient balance!"
        );
        uint256 _amount = balances[_msgSender] - voucher.updatedBalance;
        payable(msg.sender).transfer(_amount);
        balances[_msgSender] = voucher.updatedBalance;
        emit Withdrawn(_msgSender, _amount);
        /*
        Checkpoint 5: Recover earnings

        The service provider would like to cash out their hard earned ether.
            - use ecrecover on prefixedHashed and the supplied signature
            - require that the recovered signer has a running channel with balances[signer] > v.updatedBalance
            - calculate the payment when reducing balances[signer] to v.updatedBalance
            - adjust the channel balance, and pay the contract owner. (Get the owner address withthe `owner()` function)
            - emit the Withdrawn event
        */
    }

    function challengeChannel() public {
        require(balances[msg.sender] > 0, "There is no channel running!");
        canCloseAt[msg.sender] = block.timestamp + 30 seconds;
        emit Challenged(msg.sender);
    }

    /*
    Checkpoint 6a: Challenge the channel

    create a public challengeChannel() function that:
    - checks that msg.sender has an open channel
    - updates canCloseAt[msg.sender] to some future time
    - emits a Challenged event
    */

    /*
    Checkpoint 6b: Close the channel

    create a public defundChannel() function that:
    - checks that msg.sender has a closing channel
    - checks that the current time is later than the closing time
    - sends the channel's remaining funds to msg.sender, and sets the balance to 0
    - emits the Closed event
    */
    function defundChannel() public {
        require(timeLeft(msg.sender) == 0, "Channel can't be closed yet!");
        payable(msg.sender).transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
        emit Closed(msg.sender);
    }
}
