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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) {
            return a;
        } else {
            return b;
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return a;
        } else {
            return b;
        }
    }
}

library AddressesUtils {
    function contains(address[] memory addresses, address target)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == target) {
                return true;
            }
        }

        return false;
    }
}

contract Kandle {
    using SafeMath for uint256;
    using AddressesUtils for address[];

    struct Pool {
        uint256 id;
        uint256 startTs;
        uint256 endTs;
        address[] kandlersAddresses;
        uint256[] engagedAmounts;
        uint256 totalEngaged;
        uint256 totalBurned;
    }

    // Define token properties
    uint256 public decimals = 18;
    uint256 public totalSupply = 9 * 10**9 * 10**decimals;
    string public name = "Kandle";
    string public symbol = "KNDL";

    // Manage token supply
    uint256 private constant _privateSaleAllowance = 12;
    uint8 private constant _publicSaleAllowance = 30;
    uint8 private constant _teamAllowance = 10;
    uint8 private constant _treasuryAllowance = 40;
    uint8 private constant _partnershipAllowance = 8;
    address public treasuryReceiver =
        0x158d9359C28790cDcbA812428259fCa9388D92cD;
    address public eaterAddress = 0x0000000000000000000000000000000000000000;

    // Define collectors addresses
    address public feesCollector = 0x5866f300771cAb38A8180ED1bC35a19ED3f223A7;
    address public ashesCollector = 0x36f4de9BBbd72D84d2b6D53c2E79Bb879d37b6fa;
    address public burnsCollector = 0x7A90dD83b368D4D7176d0672c79147d3f04B3b65;
    address public rewardsCollector =
        0xb36FeC172E56eF545e44A9e3Ef965Dd029989902;
    address public fuelCollector = 0x55E2D8D08DAABaB8eb71b814215479beE2837944;

    // Manage Admins
    address private _superAdmin;
    mapping(address => bool) private _admins;
    bytes32 private _secretHash =
        0x86357a7cc9adf5e6904dff036878d545dabdd24f531b31a82e59f88ad0ec2d31;

    // Manage token supply
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    // Manager users
    mapping(address => bool) private _blacklist;

    // Manage fees
    uint8 private constant _txFeesMaxVal = 10;
    uint8 private constant _poolBurnsMaxVal = 50;
    uint8 private constant _rewardTxFeesMaxVal = 10;
    uint8 private _txFees = 10;
    uint8 private _poolBurns = 20;
    uint8 private _rewardTxFees = 10;

    // Manage pools
    uint8 private constant _poolSkips = 2; // Top winner should skip 2 pools
    uint32 private constant _poolTime = 172800; // Pool period in seconds (48h)
    uint8 private constant _topKandlersCount = 10; // Number of potential pool winners
    uint8 private constant _topRewardsMultiplier = 2; // Multiplier for top kandler
    mapping(uint256 => Pool) private _pools;
    uint256 public currentPoolId; // Auto increment ID
    uint256 private _currentPoolStartTs;
    bool private _poolInProgress;
    uint256 private totalEngaged;

    // Manage kandlers
    address[] private _kandlersAddresses;
    address[] private _rewardedKandlers;
    mapping(address => uint256) private _kandlers;
    uint256[] private _kandlersEngagedAmounts;
    mapping(address => uint256) private _excludedKandlers; // Mapping (address => reference pool id)

    // Manage voting
    uint32 private constant _voteTimeThreshold = 1800; // Kandlers can only enable vote 30 min before the end time
    address[] private _increaseWaxVoters;
    uint8 private constant _maxAllowedIncreasedFuel = 50; // Max percentage from fuel collector to be added in a pool upon votes
    uint8 private constant _increasedFuelFromPreviousPool = 20; // A constant percentage to be added from the previous pool left tokens

    // Manage events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event LightKandle(address indexed kandler, uint256 value);
    event Reward(address indexed kandler, uint256 value);
    event Burn(address indexed from, address indexed to, uint256 value);

    constructor() {
        _superAdmin = msg.sender;

        balances[treasuryReceiver] = totalSupply.mul(_treasuryAllowance).div(
            100
        );
        balances[msg.sender] = totalSupply
            .mul(
                _privateSaleAllowance
                    .add(_publicSaleAllowance)
                    .add(_teamAllowance)
                    .add(_partnershipAllowance)
            )
            .div(100);

        balances[feesCollector] = 0;
        balances[ashesCollector] = 0;
        balances[burnsCollector] = 0;
        balances[rewardsCollector] = 0;
        balances[fuelCollector] = 0;
    }

    modifier onlySuperAdmin(string memory secret) {
        require(msg.sender == _superAdmin, "Address is not allowed!");
        require(
            keccak256(bytes(secret)) == _secretHash,
            "Secret key is incorrect!"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == _superAdmin || _admins[msg.sender],
            "Address is not allowed!"
        );
        _;
    }

    modifier aboveZero(uint256 value) {
        require(value > 0, "Zero value not accepted!");
        _;
    }

    modifier hasBalance(address target, uint256 value) {
        require(balances[target] >= value, "Insufficient balance!");
        _;
    }

    modifier burnable(uint256 value) {
        require(
            totalSupply - value >= 0,
            "Total supply is not sufficient for burn!"
        );
        _;
    }

    modifier isKandler(address target) {
        require(_kandlers[target] > 0, "Not a kandler!");
        _;
    }

    modifier poolInProgress() {
        require(_poolInProgress, "No pool is launched yet!");
        _;
    }

    modifier noPoolInProgress() {
        require(!_poolInProgress, "A pool is already in progress!");
        _;
    }

    function getOwner() external view returns (address) {
        return _superAdmin;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balances[msg.sender] >= value, "Balance is too low!");

        // Compute tx fees
        uint256 txFeesAmount = value.mul(_txFees).div(100);
        uint256 reducedAmount = value.sub(txFeesAmount);

        // Update balances
        balances[feesCollector] = balances[feesCollector].add(txFeesAmount);
        balances[to] = balances[to].add(reducedAmount);
        balances[msg.sender] = balances[msg.sender].sub(value);

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        require(balanceOf(from) >= value, "Balance is too low!");
        require(
            allowances[from][msg.sender] >= value,
            "Insufficient allowance!"
        );

        // Compute tx fees
        uint256 txFeesAmount = value.mul(_txFees).div(100);
        uint256 reducedAmount = value.sub(txFeesAmount);

        // Update balances
        balances[feesCollector] = balances[feesCollector].add(txFeesAmount);
        balances[to] = balances[to].add(reducedAmount);
        balances[from] = balances[from].sub(value);

        emit Transfer(from, to, value);
        return true;
    }

    function allowance(address spender, uint256 value) public returns (bool) {
        allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Register an admin
    function registerAdmin(address target, string memory secret)
        external
        onlySuperAdmin(secret)
        returns (bool)
    {
        _admins[target] = true;
        return true;
    }

    // Unregister an admin
    function unregisterAdmin(address target, string memory secret)
        external
        onlySuperAdmin(secret)
        returns (bool)
    {
        require(
            _admins[target],
            "Admin does not exist or already unregistered!"
        );

        _admins[target] = false;
        return true;
    }

    // Manage exclusions
    function isBlacklisted() public view returns (bool) {
        return _blacklist[msg.sender];
    }

    function updateBlacklistState(address target, bool blacklisted)
        external
        onlyAdmin
        returns (bool)
    {
        _blacklist[target] = blacklisted;
        return true;
    }

    // Manage ecosystem fees
    function updateTxFees(uint8 newTxFees, string memory secret)
        external
        onlySuperAdmin(secret)
        aboveZero(newTxFees)
        noPoolInProgress
        returns (bool)
    {
        require(newTxFees <= _txFeesMaxVal, "New fees exceed maximum value!");

        _txFees = newTxFees;
        return true;
    }

    function updatePoolBurns(uint8 newPoolBurns, string memory secret)
        external
        onlySuperAdmin(secret)
        aboveZero(newPoolBurns)
        noPoolInProgress
        returns (bool)
    {
        require(
            newPoolBurns <= _poolBurnsMaxVal,
            "New burns exceed maximum value!"
        );

        _poolBurns = newPoolBurns;
        return true;
    }

    function updateRewardsTxFees(uint8 newRewardsTxFees, string memory secret)
        external
        onlySuperAdmin(secret)
        aboveZero(newRewardsTxFees)
        noPoolInProgress
        returns (bool)
    {
        require(
            newRewardsTxFees <= _rewardTxFeesMaxVal,
            "New fees exceed maximum value!"
        );

        _rewardTxFees = newRewardsTxFees;
        return true;
    }

    // Manage pools
    function getPoolData(uint256 id) external view returns (Pool memory) {
        return _pools[id];
    }

    function getEngagedTokens()
        external
        view
        isKandler(msg.sender)
        returns (uint256)
    {
        return _kandlers[msg.sender];
    }

    function excludedFromPool() public view returns (bool) {
        return _excludedKandlers[msg.sender].add(_poolSkips) <= currentPoolId;
    }

    function launchKandle() external onlyAdmin noPoolInProgress returns (bool) {
        // Reset pool data
        for (uint256 j = 0; j < _kandlersAddresses.length; j++) {
            delete _kandlers[_kandlersAddresses[j]];
        }
        delete _kandlersAddresses;
        delete _kandlersEngagedAmounts;
        delete _increaseWaxVoters;
        delete _rewardedKandlers;
        totalEngaged = 0;

        // Launch pool
        currentPoolId++;
        _currentPoolStartTs = block.timestamp;
        _poolInProgress = true;

        return true;
    }

    function lightKandle(uint256 engaged)
        external
        poolInProgress
        aboveZero(engaged)
        hasBalance(msg.sender, engaged)
        returns (bool)
    {
        require(!isBlacklisted(), "Kandler is blacklisted!");
        require(!excludedFromPool(), "Kandler is excluded from this pool!");

        // Compute ashes
        uint256 burnsAmount = engaged.mul(_poolBurns).div(100);
        uint256 ashesAmount = engaged.sub(burnsAmount);

        // Refuel collectors
        balances[ashesCollector] = balances[ashesCollector].add(ashesAmount);
        balances[burnsCollector] = balances[burnsCollector].add(burnsAmount);
        balances[msg.sender] = balances[msg.sender].sub(engaged);

        // Save kandler info
        if (!_kandlersAddresses.contains(msg.sender)) {
            _kandlersAddresses.push(msg.sender);
        }
        _kandlers[msg.sender] = _kandlers[msg.sender].add(engaged); // Increment engaged tokens
        totalEngaged = totalEngaged.add(engaged);

        emit LightKandle(msg.sender, engaged);
        return true;
    }

    function blowKandle()
        external
        onlyAdmin
        returns (address[] memory, uint256[] memory)
    {
        require(
            block.timestamp - _currentPoolStartTs >= _poolTime,
            "Ending date not reached yet!"
        );

        // Save end pool timestamp
        uint256 currentPoolEndTs = block.timestamp;
        _poolInProgress = false;

        // Refuel rewards/fuel collector
        collectRewards();

        // TODO: Should we put the event first? Should we take in consideration that this function can be called many times in case of an error?
        // Burn collected tokens
        uint256 totalBurned = balances[burnsCollector];
        totalSupply = totalSupply.sub(totalBurned);
        balances[burnsCollector] = balances[burnsCollector].sub(totalBurned);
        emit Burn(burnsCollector, eaterAddress, totalBurned);

        // Extract engaged amounts
        for (uint256 i = 0; i < _kandlersAddresses.length; i++) {
            _kandlersEngagedAmounts.push(_kandlers[_kandlersAddresses[i]]);
        }

        // Save pool
        _pools[currentPoolId] = Pool(
            currentPoolId,
            _currentPoolStartTs,
            currentPoolEndTs,
            _kandlersAddresses,
            _kandlersEngagedAmounts,
            totalEngaged,
            totalBurned
        );

        return (_kandlersAddresses, _kandlersEngagedAmounts);
    }

    function collectRewards() private returns (bool) {
        uint256 collectedTxFees = balances[feesCollector];
        uint256 collectedAshes = balances[ashesCollector];
        uint256 collectedRewards = collectedTxFees.add(collectedAshes);
        balances[feesCollector] = balances[feesCollector].sub(collectedTxFees);
        balances[ashesCollector] = balances[ashesCollector].sub(collectedAshes);

        uint256 rewardsTxFeesAmount = collectedRewards.mul(_rewardTxFees).div(
            100
        );
        uint256 distributedRewards = collectedRewards.sub(rewardsTxFeesAmount);
        balances[rewardsCollector] = balances[rewardsCollector].add(
            distributedRewards
        );
        balances[fuelCollector] = balances[fuelCollector].add(
            rewardsTxFeesAmount
        );

        // Increase wax depending on votes
        uint256 waxReferenceValue = balances[rewardsCollector].mul(4);
        if (
            _increaseWaxVoters.length > 0 &&
            balances[fuelCollector] >= waxReferenceValue
        ) {
            uint256 maxAllowedIncreasedWax = balances[fuelCollector]
                .mul(_maxAllowedIncreasedFuel)
                .div(100); // Max increased wax 50% of the fuel collector
            uint256 increasedWaxWeight = _increaseWaxVoters.length.div(
                _kandlersAddresses.length
            ); // Weight = voters / kandlers
            uint256 increasedWaxValue = increasedWaxWeight.mul(
                maxAllowedIncreasedWax
            ); // Compute weighted rewards

            // Refuel rewards
            balances[rewardsCollector] = balances[rewardsCollector].add(
                increasedWaxValue
            );
            balances[fuelCollector] = balances[fuelCollector].sub(
                increasedWaxValue
            );
        }

        // Increase wax from previous pools
        if (balances[fuelCollector] > 0) {
            uint256 increasedWaxFromPreviousPool = balances[fuelCollector]
                .mul(_increasedFuelFromPreviousPool)
                .div(100); // 20% from previous pool

            // Refuel rewards
            balances[rewardsCollector] = balances[rewardsCollector].add(
                increasedWaxFromPreviousPool
            );
            balances[fuelCollector] = balances[fuelCollector].sub(
                increasedWaxFromPreviousPool
            );
        }

        return true;
    }

    function rewardKandler(
        address rewardedAddress,
        uint256 index,
        bool topRewarded,
        uint256 rewards
    )
        external
        onlyAdmin
        aboveZero(rewards)
        isKandler(rewardedAddress)
        returns (bool)
    {
        require(
            balances[rewardsCollector] >= rewards,
            "Insufficient rewards balance!"
        );
        require(
            _kandlersAddresses[index] == rewardedAddress,
            "Address not included in this pool!"
        ); // Secure address
        require(
            rewards <= _kandlers[rewardedAddress].mul(_topRewardsMultiplier),
            "Rewards exceed range!"
        ); // Verify rewards
        require(
            !_rewardedKandlers.contains(rewardedAddress),
            "Kandler already rewarded!"
        ); // Verify if already rewarded

        balances[rewardedAddress] = balances[rewardedAddress].add(rewards);
        balances[rewardsCollector] = balances[rewardsCollector].sub(rewards);
        _rewardedKandlers.push(rewardedAddress);

        // Emit event only for top rewarded kandlers
        if (topRewarded) {
            // Exclude top kandler from the next x pools
            _excludedKandlers[rewardedAddress] = currentPoolId;

            emit Reward(rewardedAddress, rewards);
        }

        return true;
    }

    // Vote to increase wax
    function canIncreaseWax()
        public
        view
        poolInProgress
        isKandler(msg.sender)
        returns (uint256)
    {
        // Check if voting time
        if (
            block.timestamp - _currentPoolStartTs >=
            (_poolTime - _voteTimeThreshold)
        ) {
            return 0;
        } else {
            return
                _poolTime +
                _currentPoolStartTs -
                _voteTimeThreshold -
                block.timestamp; // 172800 + pool start time - 1800 - call time (block.timestamp)
        }
    }

    function letsIncreaseWax()
        external
        poolInProgress
        isKandler(msg.sender)
        returns (bool)
    {
        require(canIncreaseWax() == 0, "Voting is not enabled yet!");

        if (!_increaseWaxVoters.contains(msg.sender)) {
            _increaseWaxVoters.push(msg.sender);
        }

        return true;
    }

    function burn(uint256 value)
        public
        hasBalance(msg.sender, value)
        burnable(value)
    {
        balances[msg.sender] = balances[msg.sender].sub(value);
        totalSupply = totalSupply.sub(value);

        emit Burn(msg.sender, eaterAddress, value);
    }

    function kill(string memory secret) external onlySuperAdmin(secret) {
        address payable ownerAddress = payable(address(msg.sender));
        selfdestruct(ownerAddress);
    }

    receive() external payable {}
}
