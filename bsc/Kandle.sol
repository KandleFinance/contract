pragma solidity ^0.8.2;

contract Kandle {
    
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
    address public feesCollector = 0x5866f300771cAb38A8180ED1bC35a19ED3f223A7;
    address public ashesCollector = 0x36f4de9BBbd72D84d2b6D53c2E79Bb879d37b6fa;
    address public burnsCollector = 0x7A90dD83b368D4D7176d0672c79147d3f04B3b65;
    address public rewardsCollector = 0xb36FeC172E56eF545e44A9e3Ef965Dd029989902;
    address public fuelCollector = 0x55E2D8D08DAABaB8eb71b814215479beE2837944;

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
    
    // Called only once when we first deploy the smart contract
    constructor() {
        superAdmin = msg.sender;
        
        balances[treasuryReceiver] = totalSupply * treasuryAllowance / 100;
        balances[msg.sender] = totalSupply * (privateSaleAllowance + publicSaleAllowance + teamAllowance + partnershipAllowance) / 100;
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
}
