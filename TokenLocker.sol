//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";

/**
    Locks ERC20 Tokens In Contract And Tracks All Lock Data
 */
contract TokenLocker {

    // Locker Structure
    struct Lock {
        uint amountLocked;
        uint blockLocked;
        uint lockDuration;
    }

    // User -> Token -> ID -> Lock Data
    mapping ( address => mapping ( address => mapping ( uint256 => Lock ))) public userLocks;

    // User -> Token -> CurrentID
    mapping ( address => mapping ( address => uint256 )) public nonces;

    // Events
    event Lock(address indexed userLockingTokens, address token, uint256 ID, uint256 amount, uint256 durationInBlocks);
    event Unlock(address indexed recipientOfLockedTokens, address token, uint256 ID, uint256 amount);

    function timeUntilUnlock(address user, address token, uint256 ID) external view returns (uint256) {
        uint bLocked = userLocks[user][token][ID].blockLocked;
        uint duration = userLocks[user][token][ID].lockDuration;
        return bLocked + duration > block.number ? (bLocked + duration - block.number) : 0;
    }

    function getAmountLocked(address user, address token, uint256 ID) external view returns (uint256) {
        return userLocks[user][token][ID].amountLocked;
    }

    function _unlock(address token, uint256 ID, uint256 amount) internal {
        require(
            nonces[msg.sender][token] > ID,
            'Nonce Does not Match'
        );
        require(
            token != address(0) && amount > 0,
            'Zero Inputs'
        );
        require(
            userLocks[msg.sender][token][ID].amountLocked >= amount,
            'Insufficient Lock Amount'
        );
        require(
            userLocks[msg.sender][token][ID].amountLocked > 0 &&
            userLocks[msg.sender][token][ID].blockLocked > 0 &&
            userLocks[msg.sender][token][ID].blockDuration > 0,
            'Zero Values'
        );
        require(
            userLocks[msg.sender][token][ID].blockLocked + userLocks[msg.sender][token][ID].blockDuration <= block.number,
            'Lock Has Not Expired'
        );

        // update amount locked
        userLocks[msg.sender][token][ID].amountLocked -= amount;
        
        // redeem tokens for caller
        bool s = IERC20(token).transfer(msg.sender, amount);
        require(s, 'Failure On Token Transfer');

        // emit event
        emit Unlock(msg.sender, token, ID, amount);
    }

    function _lock(address token, uint256 amount, uint256 duration) internal {
        require(
            token != address(0) && amount > 0 && duration > 0,
            'Zero Inputs'
        );

        // transfer in tokens
        uint before = IERC20(token).balanceOf(address(this));
        bool s = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(s, 'Failure On Transfer From');
        uint after = IERC20(token).balanceOf(address(this));
        require(after > before, 'Zero Received');
        uint received = after - before;

        // set data
        userLocks[msg.sender][token][nonces[msg.sender][token]].amountLocked = amount;
        userLocks[msg.sender][token][nonces[msg.sender][token]].blockLocked = block.number;
        userLocks[msg.sender][token][nonces[msg.sender][token]].lockDuration = duration;

        // emit event
        emit Lock(msg.sender, token, nonces[msg.sender][token], amount, duration);

        // update nonce
        nonces[msg.sender][token]++;
    }
}