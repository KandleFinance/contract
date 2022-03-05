// SPDX-License-Identifier: Kandle
pragma solidity ^0.8.2;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract Kandle {

    // Use math librairies
    using SafeMath for uint256;

    enum TopKandlerType {
        REWARDED,
        UNREWARDED
    }

    struct TopKandler {
        address addr;
        uint256 engaged;
        uint256 rewarded;
        TopKandlerType kandlerType;
    }

    struct Pool {
        uint256 id;
        uint256 startTS;
        uint256 endTS;
        uint256 kandlersCount;
        TopKandler[] topKandlers;
    }
    
    // Define token properties
    uint public decimals = 18;
    uint public totalSupply = 9 * 10**9 * 10 ** decimals;
    string public name = "Kandle";
    string public symbol = "KNDL";

    // Manage token supply
    uint private constant _privateSaleAllowance = 12;
    uint private constant _publicSaleAllowance = 30;
    uint private constant _teamAllowance = 10;
    uint private constant _treasuryAllowance = 40;
    uint private constant _partnershipAllowance = 8; 
    address public treasuryReceiver = 0x158d9359C28790cDcbA812428259fCa9388D92cD;
    address public eaterAddress = 0x0000000000000000000000000000000000000000;

    // Define collectors addresses
    address public feesCollector = 0x5866f300771cAb38A8180ED1bC35a19ED3f223A7;
    address public ashesCollector = 0x36f4de9BBbd72D84d2b6D53c2E79Bb879d37b6fa;
    address public burnsCollector = 0x7A90dD83b368D4D7176d0672c79147d3f04B3b65;
    address public rewardsCollector = 0xb36FeC172E56eF545e44A9e3Ef965Dd029989902;
    address public fuelCollector = 0x55E2D8D08DAABaB8eb71b814215479beE2837944;

    // Manage Admins
    address private _superAdmin;
    mapping(address => bool) private _admins;
    
    // Manage token supply
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    
    // Manager users
    mapping(address => bool) private _blacklist;

    // Manage fees
    uint private constant _txFeesMaxVal = 10;
    uint private constant _poolAshesMaxVal = 70;
    uint private constant _rewardTxFeesMaxVal = 10;
    uint private _txFees = 10;
    uint private _poolAshes = 70;
    uint private _rewardTxFees = 10;

    // Manage pools
    uint8 private constant _poolSkips = 2; // Top winner should skip 2 pools
    uint32 private constant _poolTime = 172800; // Pool period in seconds (48h)
    uint8 private constant _topKandlersCount = 10; // Number of potential pool winners
    uint8 private constant _rewardsMultiplier = 2; // Multiplier for top kandler
    mapping(uint256 => Pool) private _pools;
    uint256 private _currentPoolId; // Auto increment ID
    uint256 private _currentPoolStartTimestamp;
    bool private _poolInProgress;

    address[] private _kandlersAddresses;
    mapping(address => uint256) private _kandlers;
    mapping(address => TopKandler) private _topKandlers;
    mapping(address => uint256) private _excludedKandlers; // Mapping (address => reference pool id)

    // Manage events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ToKandle(address indexed kandler, uint256 value);
    event Reward(address indexed kandler, uint256 value);
    
    constructor() {
        _superAdmin = msg.sender;
        
        balances[treasuryReceiver] = totalSupply.mul(_treasuryAllowance).div(100);
        balances[msg.sender] = totalSupply.mul(_privateSaleAllowance.add(_publicSaleAllowance).add(_teamAllowance).add(_partnershipAllowance)).div(100);

        balances[feesCollector] = 0;
        balances[ashesCollector] = 0;
        balances[burnsCollector] = 0;
        balances[rewardsCollector] = 0;
        balances[fuelCollector] = 0;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == _superAdmin, 'Address is not allowed');
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == _superAdmin || _admins[msg.sender], 'Address is not allowed');
        _;
    }

    modifier aboveZero(uint256 value) {
        require(value > 0, 'Zero value not accepted');
        _;
    }

    modifier hasBalance(address target, uint256 value) {
        require(balances[target] >= value, 'Insufficient balance!');
        _;
    }

    modifier burnable(uint256 value) {
        require(totalSupply - value >= 0, 'Total supply is not sufficient for burn!');
        _;
    }

    modifier isKandler(address target) {
        require(_kandlers[target] > 0, 'Not a kandler!');
        _;
    }

    function getOwner() external view returns(address) {
        return _superAdmin;
    }

    function balanceOf(address owner) public view returns(uint) {
        return balances[owner];
    }
    
    function transfer(address to, uint256 value) public returns(bool) {
        require(balances[msg.sender] >= value, 'Balance is too low!');

        // Compute tx fees
        uint256 txFeesAmount = value.mul(_txFees).div(100);
        uint256 reducedAmount = value.sub(txFeesAmount);
        
        // Update balances
        balances[feesCollector] += txFeesAmount;
        balances[to] += reducedAmount;
        balances[msg.sender] -= value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns(bool) {
        require(balanceOf(from) >= value, 'Balance is too low!');
        require(allowances[from][msg.sender] >= value, 'Insufficient allowance!');

        // Compute tx fees
        uint256 txFeesAmount = value.mul(_txFees).div(100);
        uint256 reducedAmount = value.sub(txFeesAmount);
        
        // Update balances
        balances[feesCollector] += txFeesAmount;
        balances[to] += reducedAmount;
        balances[from] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    function allowance(address spender, uint256 value) public returns(bool) {
        allowances[msg.sender][spender] = value;
        
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Register an admin
    function registerAdmin(address target) onlySuperAdmin() external {
        _admins[target] = true;
    }

    // Unregister an admin
    function unregisterAdmin(address target) onlySuperAdmin() external {
        require(_admins[target], 'Admin does not exist or already unregistered!');

        _admins[target] = false;
    }

    // Manage exclusions
    function isBlacklisted() public view returns(bool) {
        return _blacklist[msg.sender];
    }

    function updateBlacklistState(address target, bool blacklisted) onlyAdmin() external {
        _blacklist[target] = blacklisted;
    }

    function isExcluded() public view returns(bool) {
        return _excludedKandlers[msg.sender].add(_poolSkips) <= _currentPoolId;
    }

    // Manage ecosystem fees
    function updateTxFees(uint newTxFees) onlySuperAdmin() aboveZero(newTxFees) external {
        require(!poolInProgress(), 'A pool is already in progress!');
        require(newTxFees <= _txFeesMaxVal, 'New fees exceed maximum value!');

        _txFees = newTxFees;
    }

    function updatePoolAshes(uint newPoolAshes) onlySuperAdmin() aboveZero(newPoolAshes) external {
        require(!poolInProgress(), 'A pool is already in progress!');
        require(newPoolAshes <= _poolAshesMaxVal, 'New ashes exceed maximum value!');

        _poolAshes = newPoolAshes;
    }

    function updateRewardsTxFees(uint newRewardsTxFees) onlySuperAdmin() aboveZero(newRewardsTxFees) external {
        require(!poolInProgress(), 'A pool is already in progress!');
        require(newRewardsTxFees <= _rewardTxFeesMaxVal, 'New fees exceed maximum value!');

        _rewardTxFees = newRewardsTxFees;
    }

    // Manage pools
    function poolInProgress() public view returns(bool) {
        return _poolInProgress;
    }

    // TODO: Should we restrict to admins ?
    function getPoolData(uint256 id) external view returns(Pool memory) {
        return _pools[id];
    }

    // TODO: Should we restrict to admins ?
    function getEngagedTokens(address target) external isKandler(target) view returns(uint256) {
        return _kandlers[target];
    }

    function launchKandle() onlyAdmin() external {
        require(!poolInProgress(), 'A pool is already in progress!');
        
        _currentPoolStartTimestamp = block.timestamp;
        _poolInProgress = true;
        _currentPoolId++;
    }

    function lightKandle(uint256 amount) aboveZero(amount) external returns(bool) {
        require(poolInProgress(), 'No pool is launched yet!');
        require(!isBlacklisted(), 'Kandler is blacklisted!');
        require(!isExcluded(), 'Kandler is excluded from this pool');
        require(balanceOf(msg.sender) >= amount, 'Balance is too low!');

        // Compute ashes
        uint256 ashesAmount = amount.mul(_poolAshes).div(100);
        uint256 burnsAmount = amount.sub(ashesAmount);

        // Refuel collectors
        balances[ashesCollector] += ashesAmount;
        balances[burnsCollector] += burnsAmount;
        balances[msg.sender] -= amount;

        _kandlersAddresses.push(msg.sender);
        _kandlers[msg.sender] += amount; // Increment engaged tokens

        emit ToKandle(msg.sender, amount);
        return true;
    }

    function blowKandle() onlyAdmin() external {
        require(block.timestamp - _currentPoolStartTimestamp >= _poolTime, 'Ending date not reached yet!');

        // Save end pool timestamp
        uint256 currentPoolEndTimestamp = block.timestamp;
        
        // Refuel rewards/fuel collector
        uint256 collectedRewards = balances[feesCollector] + balances[ashesCollector];
        uint256 rewardsTxFeesAmount = collectedRewards.mul(_rewardTxFees).div(100);
        uint256 distributedRewards = collectedRewards.sub(rewardsTxFeesAmount);
        balances[rewardsCollector] = distributedRewards;
        balances[fuelCollector] += rewardsTxFeesAmount;
        balances[feesCollector] = 0;
        balances[ashesCollector] = 0;
        
        // Estimate top kandlers count
        uint potentialTopKandlers = _topKandlersCount; // Max by default
        if (_kandlersAddresses.length < _topKandlersCount) {
            potentialTopKandlers = _kandlersAddresses.length;
        }

        // Get top and sorted kandlers
        TopKandler[] memory topKandlers = new TopKandler[](potentialTopKandlers);
        for (uint8 i = 0; i < potentialTopKandlers; i++) {
            uint256 topKandlerIndex = 0;
            uint256 maxEngagedAmount = 0;

            for (uint256 j = 0; j < _kandlersAddresses.length; j++) {
                // Who has engaged more tokens and wasn't already added
                address target = _kandlersAddresses[j];
                if ((_kandlers[target] > maxEngagedAmount) && !amongTopKandlers(topKandlers, target)) {
                    topKandlerIndex = j;
                    maxEngagedAmount = _kandlers[target];
                }
            }

            // Reward top kandler
            uint256 maxRewards = topKandlers[i].engaged.mul(_rewardsMultiplier);
            if (balances[rewardsCollector] >= maxRewards) {
                // The kandler will have max rewards
                balances[topKandlers[i].addr] += maxRewards;
                balances[rewardsCollector] -= maxRewards;
                _excludedKandlers[_kandlersAddresses[topKandlerIndex]] = _currentPoolId; // Exclude kandler from the next x pools
                topKandlers[i] = TopKandler(_kandlersAddresses[topKandlerIndex], maxEngagedAmount, maxRewards, TopKandlerType.REWARDED);
                
                emit Reward(_kandlersAddresses[topKandlerIndex], maxRewards);
            } else {
                // Could not max rewards to this top kandler
                // TODO: Should we give the rest to this kandler ???
                topKandlers[i] = TopKandler(_kandlersAddresses[topKandlerIndex], maxEngagedAmount, 0, TopKandlerType.UNREWARDED);
            }
        }

        // Refuel fuel collector after rewards process
        if (balances[rewardsCollector] > 0) {
            balances[fuelCollector] += balances[rewardsCollector];
            balances[rewardsCollector] = 0;
        }

        // Empty burns collector
        uint256 burned = balances[burnsCollector];
        totalSupply -= burned;
        balances[burnsCollector] = 0;
        // TODO: Should we approve allowance first? Needs to be tested

        emit Transfer(burnsCollector, eaterAddress, burned);

        // Save/reset pool
        _pools[_currentPoolId] = Pool(_currentPoolId, _currentPoolStartTimestamp, currentPoolEndTimestamp, _kandlersAddresses.length, topKandlers);
        for (uint256 j = 0; j < _kandlersAddresses.length; j++) {
            delete _kandlers[_kandlersAddresses[j]];
        }
        delete _kandlersAddresses;
        _poolInProgress = false;
    }

    function amongTopKandlers(TopKandler[] memory topKandlers, address target) private pure returns(bool) {
        bool addressExists = false;
        uint counter = 0;
        while(!addressExists && (counter < topKandlers.length)) {
            if (topKandlers[counter].addr == target) {
                addressExists = true;
            }

            counter++;
        }

        return addressExists;
    }
    
    function burn(uint256 value) hasBalance(msg.sender, value) burnable(value) public {
        balances[msg.sender] -= value;
        totalSupply -= value;

        emit Transfer(msg.sender, eaterAddress, value);
    }

    function kill() onlySuperAdmin() external {
        address payable ownerAddress = payable(address(msg.sender));
        selfdestruct(ownerAddress);
    }
}
