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
    
    // Manager events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Manage fees
    uint private constant _txFeesMaxVal = 10;
    uint private constant _poolAshesMaxVal = 70;
    uint private constant _rewardTxFeesMaxVal = 10;
    uint private _txFees = 10;
    uint private _poolAshes = 70;
    uint private _rewardTxFees = 10;
    
    // Called only once when we first deploy the smart contract
    constructor() {
        _superAdmin = msg.sender;
        
        balances[treasuryReceiver] = totalSupply.mul(_treasuryAllowance).div(100);
        balances[msg.sender] = totalSupply.mul(_privateSaleAllowance.add(_publicSaleAllowance).add(_teamAllowance).add(_partnershipAllowance)).div(100);
    }
    
    // view means the function is readonly and it can't modify data on the blockchain
    function balanceOf(address owner) public view returns(uint) {
        return balances[owner];
    }
    
    // Transfer tokens to another address
    function transfer(address to, uint256 amount) public returns(bool) {
        require(balances[msg.sender] >= amount, 'Balance is too low!');

        // Compute tx fees
        uint256 txFeesAmount = amount.mul(_txFees).div(100);
        uint256 reducedAmount = amount.sub(txFeesAmount);
        
        // Update balances
        balances[feesCollector] += txFeesAmount;
        balances[to] += reducedAmount;
        balances[msg.sender] -= amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    // Transfer tokens from an address to another address
    function transferFrom(address from, address to, uint256 amount) public returns(bool) {
        require(balanceOf(from) >= amount, 'Balance is too low!');
        require(allowances[from][msg.sender] >= amount, 'Insufficient allowance!');

        // Compute tx fees
        uint256 txFeesAmount = amount.mul(_txFees).div(100);
        uint256 reducedAmount = amount.sub(txFeesAmount);
        
        // Update balances
        balances[feesCollector] += txFeesAmount;
        balances[to] += reducedAmount;
        balances[from] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    // Authorize an address to spend a given amount of tokens
    function authorizeAllowance(address spender, uint256 value) public returns(bool) {
        allowances[msg.sender][spender] = value;
        
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function updateAllowance(address spender, uint256 value) public returns(bool) {
        allowances[msg.sender][spender] = value;
        
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function selfBurn(uint256 value) public {
        require(isSuperAdmin(), 'Address is not allowed!'); // For the moment, only the admin can burn tokens
        require(totalSupply - value >= 0, 'Total supply is not sufficient for burn!');
        
        totalSupply -= value;

        emit Transfer(msg.sender, eaterAddress, value);
    }
    
    // Remove smart contract
    // Should be executed only from a super admin address
    function kill() public {
        require(isSuperAdmin(), 'Address is not allowed!');
        address payable ownerAddress = payable(address(msg.sender));
        selfdestruct(ownerAddress);
    }

    // Check if the calling address is the super admin
    function isSuperAdmin() public view returns(bool) {
        return msg.sender == _superAdmin;
    }

    // Check if the calling address is an admin
    function isAdmin() public view returns(bool) {
        return msg.sender == _superAdmin || _admins[msg.sender];
    }

    // Register an admin
    function registerAdmin(address target) public {
        require(isSuperAdmin(), 'Address is not allowed!');

        _admins[target] = true;
    }

    // Unregister an admin
    function unregisterAdmin(address target) public {
        require(isSuperAdmin(), 'Address is not allowed!');
        require(_admins[target], 'Admin does not exist or already unregistered!');
        
        _admins[target] = false;
    }

    // Check if user is blacklisted
    function isBlacklisted(address target) public view returns(bool) {
        return _blacklist[target];
    }

    // Manage blacklist
    function updateBlacklistState(address target, bool blacklisted) public {
        require(isSuperAdmin(), 'Address is not allowed!');

        _blacklist[target] = blacklisted;
    }

    // Manage ecosystem fees
    function updateTxFees(uint newFees) public {
        require(isSuperAdmin(), 'Address is not allowed!');
        require(newFees <= _txFeesMaxVal, 'New fees exceed maximum value!');

        _txFees = newFees;
    }

    function updatePoolAshes(uint newPoolAshes) public {
        require(isSuperAdmin(), 'Address is not allowed!');
        require(newPoolAshes <= _poolAshesMaxVal, 'New fees exceed maximum value!');

        _poolAshes = newPoolAshes;
    }

    function updateRewardsTxFees(uint newRewardsTxFees) public {
        require(isSuperAdmin(), 'Address is not allowed!');
        require(newRewardsTxFees <= _rewardTxFeesMaxVal, 'New fees exceed maximum value!');

        _rewardTxFees = newRewardsTxFees;
    }
}
