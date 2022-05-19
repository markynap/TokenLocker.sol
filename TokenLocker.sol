//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";

contract TokenLocker {

    // List Of Token Lock Information
    struct TokenLockInfo {
        address token;
        address lockAddress;
        uint256 lockAmount;
        uint256 lockExpiration;
    }

    // ID -> Token Lock Info
    mapping ( uint256 => TokenLockInfo ) public lockInfo;

    // User -> ID[]
    mapping ( address => uint256[] ) public userInfo;

    // Global Nonce
    uint256 public nonce;

    // Events
    event Locked(address token, uint256 amount, uint256 ID, uint256 duration);
    event Unlocked(address token, uint256 amount, uint256 ID);
    event Relocked(address token, uint256 amount, uint256 ID, uint256 newDuration);

    function lock(address token, uint256 amount, uint256 duration) external returns (uint256 ID) {
        
        // transfer in locked token
        uint received = _transferIn(token, amount);

        // Set Lock Info For ID
        lockInfo[nonce].token = token;
        lockInfo[nonce].lockAddress = msg.sender;
        lockInfo[nonce].lockAmount = received;
        lockInfo[nonce].lockExpiration = block.number + duration;

        // Add To User's List Of Lock IDs
        userInfo[msg.sender].push(nonce);
        
        // emit Lock Event
        emit Locked(token, received, nonce, duration);

        // Increment Nonce
        nonce++;

        // return ID Used
        return nonce - 1;
    }

    function unlock(uint256 ID) external {
        
        // Fetch Data From ID
        address unlocker   = lockInfo[ID].lockAddress;
        uint256 lockAmount = lockInfo[ID].lockAmount;
        uint256 lockExpiry = lockInfo[ID].lockExpiration;

        // Require Conditions Are Met
        require(
            msg.sender == unlocker,
            'Only Unlocker Can Unlock'
        );
        require(
            lockExpiry <= block.number,
            'Lock Has Not Expired'
        );
        require(
            lockAmount > 0,
            'Nothing To Unlock'
        );

        // reset lock amount
        delete lockInfo[ID].lockAmount;
        
        // remove ID from user's list of lock IDs
        _removeID(unlocker, ID);

        // transfer locked tokens to unlocker address
        require(
            IERC20(lockInfo[ID].token).transfer(
                unlocker,
                lockAmount
            ),
            'Failure On Token Transfer'
        );

        // emit Unlocked Event
        emit Unlocked(lockInfo[ID].token, lockAmount, ID);
    }

    function relock(uint256 ID, uint256 newLockDuration) external {

        // Fetch Data From ID
        address unlocker   = lockInfo[ID].lockAddress;
        uint256 lockAmount = lockInfo[ID].lockAmount;
        uint256 lockExpiry = lockInfo[ID].lockExpiration;

        // Require Conditions Are Met
        require(
            msg.sender == unlocker,
            'Only Unlocker Can Unlock'
        );
        require(
            lockExpiry <= block.number,
            'Lock Has Not Expired'
        );
        require(
            lockAmount > 0,
            'Nothing To ReLock'
        );

        // set new expiration date
        lockInfo[ID].lockExpiration = block.number + newLockDuration;

        // emit Relocked Event
        emit Relocked(lockInfo[ID].token, lockAmount, ID, newLockDuration);
    }

    function _transferIn(address token, uint256 amount) internal returns (uint256) {
        uint before = IERC20(token).balanceOf(address(this));
        require(
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            'Error On Transfer From'
        );
        uint After = IERC20(token).balanceOf(address(this));
        require(
            After > before,
            'Zero Tokens Received'
        );
        return After - before;
    }

    function _removeID(address user, uint256 ID) internal {

        uint index = userInfo[user].length;
        for (uint i = 0; i < userInfo[user].length; i++) {
            if (userInfo[user][i] == ID) {
                index = i;
                break;
            }
        }
        require(index < userInfo[user].length, 'ID Not Found');

        userInfo[user][index] = userInfo[user][userInfo[user].length - 1];
        userInfo[user].pop();
    }

    function timeUntilUnlock(uint256 ID) external view returns (uint256) {
        uint unlocksAt = lockInfo[ID].lockExpiration;
        return unlocksAt > block.number ? unlocksAt - block.number : 0;
    }

    function listLockIDs(address user) external view returns (uint256[] memory) {
        return userInfo[user];
    }

}