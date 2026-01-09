// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Ktv2OwnershipTimelock
 * @notice Timelock mechanism for temporarily freezing Ktv2 contract ownership
 * @dev Designed for a specific Ktv2 contract address set at deployment
 */
contract Ktv2OwnershipTimelock is ReentrancyGuard {
    
    address public immutable ktv2Contract;
    
    uint256 public constant MIN_FREEZE_DURATION = 3600;      // 1 hour in seconds
    uint256 public constant MAX_FREEZE_DURATION = 31536000;  // 365 days in seconds
    
    struct Lock {
        address originalOwner;
        uint256 unlockTime;
        bool active;
    }
    
    Lock public currentLock;
    address public registeredOwner;
    
    event OwnerRegistered(address indexed owner);
    event OwnershipFrozen(address indexed owner, uint256 unlockTime, uint256 duration);
    event OwnershipRestored(address indexed owner, uint256 timestamp);
    event FreezeExtended(address indexed owner, uint256 newUnlockTime, uint256 additionalDuration);
    
    /**
     * @notice Initialize timelock for specific Ktv2 contract
     * @param _ktv2Contract Ktv2 contract address to manage
     */
    constructor(address _ktv2Contract) {
        require(_ktv2Contract != address(0), "Invalid address");
        ktv2Contract = _ktv2Contract;
    }
    
    /**
     * @notice Register caller as original owner
     * @dev Caller must be current Ktv2 owner and contract must not be frozen
     */
    function registerOriginalOwner() external {
        require(!currentLock.active, "Cannot register while frozen");
        require(Ownable(ktv2Contract).owner() == msg.sender, "Not Ktv2 owner");
        
        registeredOwner = msg.sender;
        emit OwnerRegistered(msg.sender);
    }
    
    /**
     * @notice Freeze ownership for specified duration
     * @param duration Freeze duration in seconds
     */
    function freezeOwnership(uint256 duration) external nonReentrant {
        require(!currentLock.active, "Already frozen");
        require(msg.sender == registeredOwner, "Not registered");
        require(Ownable(ktv2Contract).owner() == address(this), "Transfer ownership first");
        require(duration >= MIN_FREEZE_DURATION, "Below minimum");
        require(duration <= MAX_FREEZE_DURATION, "Exceeds maximum");
        
        currentLock = Lock({
            originalOwner: msg.sender,
            unlockTime: block.timestamp + duration,
            active: true
        });
        
        emit OwnershipFrozen(msg.sender, currentLock.unlockTime, duration);
    }
    
    /**
     * @notice Restore ownership to original owner
     * @dev Callable only by original owner after unlock time expires
     */
    function restoreOwnership() external nonReentrant {
        require(currentLock.active, "No active freeze");
        require(msg.sender == currentLock.originalOwner, "Not original owner");
        require(block.timestamp >= currentLock.unlockTime, "Not expired");
        
        address owner = currentLock.originalOwner;
        
        delete currentLock;
        delete registeredOwner;
        
        Ownable(ktv2Contract).transferOwnership(owner);
        
        emit OwnershipRestored(owner, block.timestamp);
    }
    
    /**
     * @notice Extend current freeze period
     * @param additionalDuration Additional seconds to extend
     */
    function extendFreeze(uint256 additionalDuration) external nonReentrant {
        require(currentLock.active, "No active freeze");
        require(msg.sender == currentLock.originalOwner, "Not original owner");
        require(additionalDuration > 0, "Invalid duration");
        
        uint256 newUnlockTime = currentLock.unlockTime + additionalDuration;
        require(newUnlockTime <= block.timestamp + MAX_FREEZE_DURATION, "Exceeds maximum");
        
        currentLock.unlockTime = newUnlockTime;
        
        emit FreezeExtended(currentLock.originalOwner, newUnlockTime, additionalDuration);
    }
    
    /**
     * @notice Get remaining time until unlock
     * @return Seconds remaining, or 0 if not frozen or expired
     */
    function timeUntilRestore() external view returns (uint256) {
        if (!currentLock.active || block.timestamp >= currentLock.unlockTime) {
            return 0;
        }
        return currentLock.unlockTime - block.timestamp;
    }
    
    /**
     * @notice Check if ownership can be restored
     * @return True if freeze expired
     */
    function canRestore() external view returns (bool) {
        return currentLock.active && block.timestamp >= currentLock.unlockTime;
    }
    
    /**
     * @notice Get complete lock state
     * @return originalOwner Address that froze ownership
     * @return unlockTime Unlock timestamp
     * @return timeRemaining Seconds until unlock
     * @return isFrozen Current freeze status
     * @return canRestoreNow Whether restoration is available
     * @return currentRegisteredOwner Currently registered owner address
     */
    function getLockStatus() external view returns (
        address originalOwner,
        uint256 unlockTime,
        uint256 timeRemaining,
        bool isFrozen,
        bool canRestoreNow,
        address currentRegisteredOwner
    ) {
        uint256 remaining = 0;
        if (currentLock.active && block.timestamp < currentLock.unlockTime) {
            remaining = currentLock.unlockTime - block.timestamp;
        }
        
        return (
            currentLock.originalOwner,
            currentLock.unlockTime,
            remaining,
            currentLock.active,
            currentLock.active && block.timestamp >= currentLock.unlockTime,
            registeredOwner
        );
    }
}