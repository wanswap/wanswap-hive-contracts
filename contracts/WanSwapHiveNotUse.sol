// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './IWWAN.sol';

contract WanSwapHive is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of wanWans
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accwanWanPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accwanWanPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20  lpToken;          // Address of LP token contract.
        uint256 currentSupply;   //
        uint256 bonusStartBlock;  //
        uint256 bonusEndBlock;    // Block number when bonus period ends.

        uint256 lastRewardBlock;  // Last block number that wanWans distribution occurs.
        uint256 accwanWanPerShare;// Accumulated wanWans per share, times 1e12. See below.
        uint256 rewardPerBlock;   // tokens reward per block.
        address rewardToken;      // token address for reward
    }

    IWWAN public wwan;            // The WWAN contract
    PoolInfo[] public poolInfo;   // Info of each pool.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;// Info of each user that stakes LP tokens.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event QuitWanwan(address to, uint256 amount);
    event EmergencyQuitWanwan(address to, uint256 amount);

    constructor(IWWAN _wwan) public {
        wwan = _wwan;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(IERC20 _lpToken,
                 uint256 _bonusStartBlock,
                 uint256 _bonusEndBlock,
                 uint256 _rewardPerBlock,
                 address _rewardToken
                 ) public onlyOwner {
        require(block.number < _bonusEndBlock, "block.number >= bonusEndBlock");
        require(_bonusStartBlock < _bonusEndBlock, "_bonusStartBlock >= _bonusEndBlock");
        require(address(_lpToken) != address(0), "_lpToken == 0");

        uint256 lastRewardBlock = block.number > _bonusStartBlock ? block.number : _bonusStartBlock;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            currentSupply: 0,
            bonusStartBlock: _bonusStartBlock,
            bonusEndBlock: _bonusEndBlock,
            lastRewardBlock: lastRewardBlock,
            accwanWanPerShare: 0,
            rewardPerBlock: _rewardPerBlock,
            rewardToken: _rewardToken
        }));
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) internal pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending wanWans on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256,uint256) {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accwanWanPerShare = pool.accwanWanPerShare;

        uint256 curBlockNumber = (block.number < pool.bonusEndBlock) ? block.number : pool.bonusEndBlock;
        if (curBlockNumber > pool.lastRewardBlock && pool.currentSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, curBlockNumber);
            uint256 wanWanReward = multiplier.mul(pool.rewardPerBlock);
            accwanWanPerShare = accwanWanPerShare.add(wanWanReward.mul(1e12).div(pool.currentSupply));
        }
        return (user.amount, user.amount.mul(accwanWanPerShare).div(1e12).sub(user.rewardDebt));
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 curBlockNumber = (block.number < pool.bonusEndBlock) ? block.number : pool.bonusEndBlock;
        if (curBlockNumber <= pool.lastRewardBlock) {
            return;
        }

        if (pool.currentSupply == 0) {
            pool.lastRewardBlock = curBlockNumber;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, curBlockNumber);
        uint256 wanWanReward = multiplier.mul(pool.rewardPerBlock);
        pool.accwanWanPerShare = pool.accwanWanPerShare.add(wanWanReward.mul(1e12).div(pool.currentSupply));
        pool.lastRewardBlock = curBlockNumber;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(block.number < pool.bonusEndBlock,"already end");
        
        updatePool(_pid);
        
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 pending = user.amount.mul(pool.accwanWanPerShare).div(1e12).sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accwanWanPerShare).div(1e12);
        
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        pool.currentSupply = pool.currentSupply.add(_amount);

        if(pending > 0) {
            if (pool.rewardToken == address(wwan)) { // convert wwan to wan 
                wwan.withdraw(pending);
                msg.sender.transfer(pending);
            } else {
                require(IERC20(pool.rewardToken).transfer(msg.sender, pending), 'transfer token failed');
            }
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accwanWanPerShare).div(1e12).sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accwanWanPerShare).div(1e12);
        
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.currentSupply = pool.currentSupply.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }

        if(pending > 0) {
            if (pool.rewardToken == address(wwan)) { // convert wwan to wan 
                wwan.withdraw(pending);
                msg.sender.transfer(pending);
            } else {
                require(IERC20(pool.rewardToken).transfer(msg.sender, pending), 'transfer token failed');
            }
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        if(user.amount > 0){
            pool.currentSupply = pool.currentSupply.sub(user.amount);
            uint _amount = user.amount;
            user.amount = 0;
            user.rewardDebt = 0;
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function quitRewardToken(address payable _to, address rewardToken) public onlyOwner {
        require(_to != address(0), "_to == 0");
        uint balance = IERC20(rewardToken).balanceOf(address(this));
        require(IERC20(rewardToken).transfer(_to, balance), 'transfer token failed');
    }

    receive() external payable {
        require(msg.sender == address(wwan), "Only support value from WWAN"); // only accept WAN via fallback from the WWAN contract
    }
}
