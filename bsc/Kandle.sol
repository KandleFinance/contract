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

    function toDecimals(uint256 a) internal pure returns (uint256) {
        return mul(a, 10**18);
    }

    function toDivider(uint256 a) internal pure returns (uint256) {
        return div(a, 10**18);
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

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Address is not allowed!");
        _;
    }

    function owner() internal view returns (address) {
        return _owner;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner() {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner)
        public
        onlyOwner()
    {
        require(newOwner != address(0), "Invalid new owner address!");

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Kandle is Ownable {
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

    uint256 public decimals = 18;
    uint256 public totalSupply = 9 * 10**9 * 10**decimals;
    string public name = "Kandle";
    string public symbol = "KNDL";

    address public treasuryReceiver;
    address public eaterAddress = 0x0000000000000000000000000000000000000000;

    address public feesCollector;
    address public ashesCollector;
    address public burnsCollector;
    address public rewardsCollector;
    address public fuelCollector;

    mapping(address => bool) private _admins;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    mapping(address => bool) private _blacklist;

    uint8 private constant _txFeesMaxVal = 10;
    uint8 private constant _poolBurnsMaxVal = 50;
    uint8 private constant _rewardTxFeesMaxVal = 10;
    bool public feelessTxMode = false;
    uint8 public txFees = 10;
    uint8 public poolBurns = 20;
    uint8 public rewardTxFees = 10;
    uint8 public waxReferenceMultiplier = 4;

    uint32 public poolTime = 172800;
    uint8 public constant poolSkips = 2;
    uint8 public constant topKandlersCount = 10;
    uint8 public constant topRewardsMultiplier = 2;
    mapping(uint256 => Pool) private _pools;
    uint256 public currentPoolId;
    uint256 private _currentPoolStartTs;
    uint256 private _totalEngaged;
    uint256 private _totalBurned;
    bool private _poolInProgress;
    bool private _poolRewardsCollected;
    bool private _poolTokensBurned;
    bool private _poolSaved;

    address[] private _kandlersAddresses;
    address[] private _rewardedKandlers;
    mapping(address => uint256) private _kandlers;
    uint256[] private _kandlersEngagedAmounts;
    mapping(address => uint256) private _excludedKandlers;

    uint32 public voteTimeThreshold = 1800;
    address[] private _increaseWaxVoters;
    uint8 private constant _maxAllowedIncreasedFuel = 50;
    uint8 private constant _increasedFuelFromPreviousPool = 20;

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
        treasuryReceiver = 0x158d9359C28790cDcbA812428259fCa9388D92cD;
        feesCollector = 0x5866f300771cAb38A8180ED1bC35a19ED3f223A7;
        ashesCollector = 0x36f4de9BBbd72D84d2b6D53c2E79Bb879d37b6fa;
        burnsCollector = 0x7A90dD83b368D4D7176d0672c79147d3f04B3b65;
        rewardsCollector = 0xb36FeC172E56eF545e44A9e3Ef965Dd029989902;
        fuelCollector = 0x55E2D8D08DAABaB8eb71b814215479beE2837944;

        uint256 _privateSaleAllowance = 12;
        uint8 _publicSaleAllowance = 30;
        uint8 _teamAllowance = 10;
        uint8 _treasuryAllowance = 40;
        uint8 _partnershipAllowance = 8;

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

    modifier onlyAdmin() {
        require(isOwner() || _admins[msg.sender], "Address is not allowed!");
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
        return owner();
    }

    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balances[msg.sender] >= value, "Balance is too low!");

        if (feelessTxMode) {
            balances[to] = balances[to].add(value);
        } else {
            uint256 txFeesAmount = value.mul(txFees).div(100);
            uint256 reducedAmount = value.sub(txFeesAmount);

            balances[feesCollector] = balances[feesCollector].add(txFeesAmount);
            balances[to] = balances[to].add(reducedAmount);
        }
        
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

        if (feelessTxMode) {
            balances[to] = balances[to].add(value);
        } else {
            uint256 txFeesAmount = value.mul(txFees).div(100);
            uint256 reducedAmount = value.sub(txFeesAmount);

            balances[feesCollector] = balances[feesCollector].add(txFeesAmount);
            balances[to] = balances[to].add(reducedAmount);
        }
        
        balances[from] = balances[from].sub(value);

        emit Transfer(from, to, value);
        return true;
    }

    function allowance(address spender, uint256 value) public returns (bool) {
        allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    function registerAdmin(address target)
        external
        onlyOwner()
        returns (bool)
    {
        _admins[target] = true;
        return true;
    }

    function unregisterAdmin(address target)
        external
        onlyOwner()
        returns (bool)
    {
        require(
            _admins[target],
            "Admin does not exist or already unregistered!"
        );

        _admins[target] = false;
        return true;
    }

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

    function setCollectors(
        address treasury,
        address fees,
        address ashes,
        address burns,
        address rewards,
        address fuel
    ) external onlyOwner() returns (bool) {
        treasuryReceiver = treasury;
        feesCollector = fees;
        ashesCollector = ashes;
        burnsCollector = burns;
        rewardsCollector = rewards;
        fuelCollector = fuel;
        return true;
    }

    function updateFeelessTxMode(bool feelessTxModeEnabled)
        external
        onlyOwner()
        returns (bool)
    {
        feelessTxMode = feelessTxModeEnabled;
        return true;
    }

    function updatePoolTime(uint32 newPooltime)
        external
        onlyOwner()
        aboveZero(newPooltime)
        returns (bool)
    {
        poolTime = newPooltime;
        return true;
    }

    function updateVoteThreshold(uint32 newVoteThreshold)
        external
        onlyOwner()
        aboveZero(newVoteThreshold)
        returns (bool)
    {
        voteTimeThreshold = newVoteThreshold;
        return true;
    }

    function updateTxFees(uint8 newTxFees)
        external
        onlyOwner()
        aboveZero(newTxFees)
        noPoolInProgress
        returns (bool)
    {
        require(newTxFees <= _txFeesMaxVal, "New fees exceed maximum value!");

        txFees = newTxFees;
        return true;
    }

    function updatePoolBurns(uint8 newPoolBurns)
        external
        onlyOwner()
        aboveZero(newPoolBurns)
        noPoolInProgress
        returns (bool)
    {
        require(
            newPoolBurns <= _poolBurnsMaxVal,
            "New burns exceed maximum value!"
        );

        poolBurns = newPoolBurns;
        return true;
    }

    function updateRewardsTxFees(uint8 newRewardsTxFees)
        external
        onlyOwner()
        aboveZero(newRewardsTxFees)
        noPoolInProgress
        returns (bool)
    {
        require(
            newRewardsTxFees <= _rewardTxFeesMaxVal,
            "New fees exceed maximum value!"
        );

        rewardTxFees = newRewardsTxFees;
        return true;
    }

    function updateWaxReferenceMultiplier(
        uint8 newWaxReferenceMultiplier
    )
        external
        onlyOwner()
        aboveZero(newWaxReferenceMultiplier)
        noPoolInProgress
        returns (bool)
    {
        waxReferenceMultiplier = newWaxReferenceMultiplier;
        return true;
    }

    function getPoolData(uint256 id) external view returns (Pool memory) {
        require(id <= currentPoolId, "Invalid pool id!");
        return _pools[id];
    }

    function getCurrentPoolData()
        external
        view
        poolInProgress
        returns (uint256, uint256)
    {
        return (_currentPoolStartTs, _totalEngaged);
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
        return
            _excludedKandlers[msg.sender] > 0 &&
            _excludedKandlers[msg.sender].add(poolSkips) >= currentPoolId;
    }

    function launchKandle() external onlyAdmin noPoolInProgress returns (bool) {
        if (balances[rewardsCollector] > 0) {
            uint256 leftRewards = balances[rewardsCollector];
            balances[rewardsCollector] = balances[rewardsCollector].sub(
                leftRewards
            );
            balances[fuelCollector] = balances[fuelCollector].add(leftRewards);
        }

        for (uint256 j = 0; j < _kandlersAddresses.length; j++) {
            delete _kandlers[_kandlersAddresses[j]];
        }
        delete _kandlersAddresses;
        delete _kandlersEngagedAmounts;
        delete _increaseWaxVoters;
        delete _rewardedKandlers;
        _totalEngaged = 0;
        _totalBurned = 0;
        _poolRewardsCollected = false;
        _poolTokensBurned = false;
        _poolSaved = false;

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
        require(
            block.timestamp - _currentPoolStartTs <= poolTime,
            "Ending date reached!"
        );

        uint256 burnsAmount = engaged.mul(poolBurns).div(100);
        uint256 ashesAmount = engaged.sub(burnsAmount);

        balances[ashesCollector] = balances[ashesCollector].add(ashesAmount);
        balances[burnsCollector] = balances[burnsCollector].add(burnsAmount);
        balances[msg.sender] = balances[msg.sender].sub(engaged);

        if (!_kandlersAddresses.contains(msg.sender)) {
            _kandlersAddresses.push(msg.sender);
        }
        _kandlers[msg.sender] = _kandlers[msg.sender].add(engaged);
        _totalEngaged = _totalEngaged.add(engaged);

        emit LightKandle(msg.sender, engaged);
        return true;
    }

    function blowKandle()
        external
        onlyAdmin
        returns (address[] memory, uint256[] memory)
    {
        require(
            block.timestamp - _currentPoolStartTs >= poolTime,
            "Ending date not reached yet!"
        );

        _poolInProgress = false;

        if (!_poolRewardsCollected) {
            collectRewards();
            _poolRewardsCollected = true;
        }

        if (!_poolTokensBurned) {
            _totalBurned = balances[burnsCollector];
            totalSupply = totalSupply.sub(_totalBurned);
            balances[burnsCollector] = balances[burnsCollector].sub(
                _totalBurned
            );
            emit Burn(burnsCollector, eaterAddress, _totalBurned);
            _poolTokensBurned = true;
        }

        if (!_poolSaved) {
            for (uint256 i = 0; i < _kandlersAddresses.length; i++) {
                _kandlersEngagedAmounts.push(_kandlers[_kandlersAddresses[i]]);
            }

            uint256 currentPoolEndTs = block.timestamp;
            _pools[currentPoolId] = Pool(
                currentPoolId,
                _currentPoolStartTs,
                currentPoolEndTs,
                _kandlersAddresses,
                _kandlersEngagedAmounts,
                _totalEngaged,
                _totalBurned
            );
            _poolSaved = true;
        }

        return (_kandlersAddresses, _kandlersEngagedAmounts);
    }

    function collectRewards() private returns (bool) {
        uint256 collectedTxFees = balances[feesCollector];
        uint256 collectedAshes = balances[ashesCollector];
        uint256 collectedRewards = collectedTxFees.add(collectedAshes);
        balances[feesCollector] = balances[feesCollector].sub(collectedTxFees);
        balances[ashesCollector] = balances[ashesCollector].sub(collectedAshes);

        uint256 rewardsTxFeesAmount = collectedRewards.mul(rewardTxFees).div(
            100
        );
        uint256 distributedRewards = collectedRewards.sub(rewardsTxFeesAmount);
        balances[rewardsCollector] = balances[rewardsCollector].add(
            distributedRewards
        );
        balances[fuelCollector] = balances[fuelCollector].add(
            rewardsTxFeesAmount
        );

        uint256 waxReferenceValue = balances[rewardsCollector].mul(
            waxReferenceMultiplier
        );
        if (
            _increaseWaxVoters.length > 0 &&
            balances[fuelCollector] >= waxReferenceValue
        ) {
            uint256 maxAllowedIncreasedWax = balances[fuelCollector]
                .mul(_maxAllowedIncreasedFuel)
                .div(100);

            uint256 increasedWaxWeight = _increaseWaxVoters
                .length
                .toDecimals()
                .div(_kandlersAddresses.length);

            uint256 increasedWaxValue = increasedWaxWeight
                .mul(maxAllowedIncreasedWax)
                .toDivider();

            balances[rewardsCollector] = balances[rewardsCollector].add(
                increasedWaxValue
            );
            balances[fuelCollector] = balances[fuelCollector].sub(
                increasedWaxValue
            );
        }

        if (balances[fuelCollector] > 0) {
            uint256 increasedWaxFromPreviousPool = balances[fuelCollector]
                .mul(_increasedFuelFromPreviousPool)
                .div(100);

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
        );
        require(
            rewards <= _kandlers[rewardedAddress].mul(topRewardsMultiplier),
            "Rewards exceed range!"
        );
        require(
            !_rewardedKandlers.contains(rewardedAddress),
            "Kandler already rewarded!"
        );

        balances[rewardedAddress] = balances[rewardedAddress].add(rewards);
        balances[rewardsCollector] = balances[rewardsCollector].sub(rewards);
        _rewardedKandlers.push(rewardedAddress);

        if (topRewarded) {
            _excludedKandlers[rewardedAddress] = currentPoolId;

            emit Reward(rewardedAddress, rewards);
        }

        return true;
    }

    function canIncreaseWax()
        public
        view
        poolInProgress
        isKandler(msg.sender)
        returns (uint256)
    {
        if (
            block.timestamp - _currentPoolStartTs >=
            (poolTime - voteTimeThreshold)
        ) {
            return 0;
        } else {
            return
                poolTime +
                _currentPoolStartTs -
                voteTimeThreshold -
                block.timestamp;
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

    function kill() external onlyOwner() {
        address payable ownerAddress = payable(address(msg.sender));
        selfdestruct(ownerAddress);
    }

    receive() external payable {}
}
