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
    uint private privateSaleAllowance = 12;
    uint private publicSaleAllowance = 30;
    uint private teamAllowance = 10;
    uint private treasuryAllowance = 40;
    uint private partnershipAllowance = 8; 
    address public treasuryReceiver = 0x158d9359C28790cDcbA812428259fCa9388D92cD;
    address public eaterAddress = 0x0000000000000000000000000000000000000000;

    // Define collectors addresses
    address public feesCollectorAddress = 0x5866f300771cAb38A8180ED1bC35a19ED3f223A7;
    address public ashesCollectorAddress = 0x36f4de9BBbd72D84d2b6D53c2E79Bb879d37b6fa;
    address public burnsCollectorAddress = 0x7A90dD83b368D4D7176d0672c79147d3f04B3b65;
    address public rewardsCollectorAddress = 0xb36FeC172E56eF545e44A9e3Ef965Dd029989902;
    address public fuelCollectorAddress = 0x55E2D8D08DAABaB8eb71b814215479beE2837944;

    // Manage Admins
    address private superAdmin;
    mapping(address => bool) private admins;
    
    // Manage token supply
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    
    // Manager users
    mapping(address => bool) private blacklist;
    
    // Manager events
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);

    // Manage fees
    uint private txFees = 10;
    uint private poolQuota = 70; // Ashes
    uint private rewardTxFees = 10;

    // Burning process
    mapping (address => uint256) private feesCollector;
    mapping (address => uint256) private ashesCollector;
    mapping (address => uint256) private burnsCollector;
    mapping (address => uint256) private rewardsCollector;
    mapping (address => uint256) private fuelCollector;
    
    // Called only once when we first deploy the smart contract
    constructor() {
        superAdmin = msg.sender;
        
        balances[treasuryReceiver] = totalSupply.mul(treasuryAllowance).div(100);
        balances[msg.sender] = totalSupply.mul(privateSaleAllowance.add(publicSaleAllowance).add(teamAllowance).add(partnershipAllowance)).div(100);
    }
    
    // view means the function is readonly and it can't modify data on the blockchain
    function balanceOf(address owner) public view returns(uint) {
        return balances[owner];
    }
    
    // Transfer tokens to another address
    function transfer(address to, uint value) public returns(bool) {
        require(balances[msg.sender] >= value, 'Balance is too low!');
        
        balances[to] += value;
        balances[msg.sender] -= value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    // Transfer tokens from an address to another address
    function transferFrom(address from, address to, uint value) public returns(bool) {
        require(balanceOf(from) >= value, 'Balance is too low!');
        require(allowances[from][msg.sender] >= value, 'Address is not allowed!');
        
        balances[to] += value;
        balances[from] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    // Authorize an address to spend a given amount of tokens
    function approve(address spender, uint value) public returns(bool) {
        require(isAdmin(), 'Address is not allowed!');
        allowances[msg.sender][spender] = value;
        
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    // Remove an amount of tokens from the total supply
    function burn(uint value) public {
        require(isAdmin(), 'Address is not allowed!'); // For the moment, only the admin can burn tokens
        require(totalSupply - value >= 0, 'Total supply is not sufficient for burn!');
        
        totalSupply -= value;
    }
    
    // Remove smart contract
    // Should be executed only from an admin address
    function kill() public {
        require(isSuperAdmin(), 'Address is not allowed!');
        address payable ownerAddress = payable(address(msg.sender));
        selfdestruct(ownerAddress);
    }

    // Check if the calling address is the super admin
    function isSuperAdmin() public view returns(bool) {
        return msg.sender == superAdmin;
    }

    // Check if the calling address is an admin
    function isAdmin() public view returns(bool) {
        return msg.sender == superAdmin || admins[msg.sender];
    }

    // Register an admin
    function registerAdmin(address target) public {
        require(isSuperAdmin(), 'Address is not allowed!');

        admins[target] = true;
    }

    // Unregister an admin
    function unregisterAdmin(address target) public {
        require(isSuperAdmin(), 'Address is not allowed!');
        require(admins[target], 'Admin does not exist or already unregistered!');
        
        admins[target] = false;
    }

    // Check if user is blacklisted
    function isBlacklisted(address target) public view returns(bool) {
        return blacklist[target];
    }

    // Manage blacklist
    function updateBlacklistState(address target, bool blacklisted) public {
        require(isSuperAdmin(), 'Address is not allowed!');

        blacklist[target] = blacklisted;
    }
}
