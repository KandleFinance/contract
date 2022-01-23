pragma solidity ^0.8.2;

contract SelfDestruct {
    
    address private superAdmin;
    mapping(address => bool) private admins;
    
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowances;
    
    uint public totalSupply = 1000000000000 * 10 ** 18;
    string public name = "Self-destruct";
    string public symbol = "SDST";
    uint public decimals = 18;
    
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    // Called only once when we deploy the smart contract
    constructor() {
        superAdmin = msg.sender;
        admins[msg.sender] = true;
        
        balances[msg.sender] = totalSupply;
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
