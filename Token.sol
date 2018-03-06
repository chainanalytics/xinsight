pragma solidity ^0.4.20;


contract MigrationAgent {
    function migrateFrom(address _from, uint _value) public;
}


/// Xinsight crowdfunding code
contract XInsight {

    string public constant NAME = "XInsight";
    string public constant SYMBOL = "XIN";
    uint8 public constant DECIMALS = 18;

    uint public constant CREATION_RATE = 1000;

    // Funding minimums and maximums in weis
    //<><> to do - test max and min on test netrowk
    uint public constant CREATION_CAP = 200000 ether * CREATION_RATE;
    uint public constant CREATION_MIN = 20 ether * CREATION_RATE;

    uint public startBlock;
    uint public endBlock;

    //flag indicates if contract is in funding state
    bool public funding = true;

    //recieves funding ETH and XIN endowment
    address public xinHome;

    //owner of toke migrationz for newer versions
    address public migrationMaster;

    XINAllocation public allocation;  //<><> figure this part out!

    //total XIN supply
    uint public totalXIN;

    mapping(address => uint) public balances;

    address public migrationAgent;
    uint public totalMigrated;

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Migrate(address indexed _from, address indexed _to, uint _value);
    event Refund(address indexed _from, uint _value);

    function  xInsight(address _xinHome, address _migrationMaster, uint _startBlock, uint _endBlock) public
    {
        require(_xinHome != 0);
        require(_migrationMaster != 0);
        require(_startBlock > block.number);
        require(_endBlock > _startBlock);

        allocation = XINAllocation(_xinHome);
        migrationMaster = _migrationMaster;
        xinHome = _xinHome;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    function transferXIN(address _to, uint _value) public returns (bool)

    {
        require(funding == false);

        uint senderBalance = balances[msg.sender];
        if (senderBalance >= _value && _value > 0) {
            senderBalance -= _value;
            balances[msg.sender] = senderBalance;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    //figure out error below <><>
    function totalSupply() public constant returns (uint) {
        return totalXIN;
    }

    function balanceOf(address _owner) public constant returns  (uint) {
        return balances[_owner];
    }

    function migrateXIN(uint _value) public {
        require(funding == false);
        require(migrationAgent != 0);

        require(_value != 0);
        require(_value <= balances[msg.sender]);

        balances[msg.sender] -= _value;
        totalXIN -= _value;
        totalMigrated += _value;
        Migrate(msg.sender, migrationAgent, _value);
    }

    /// @notice Set address of migration target contract and enable migration
    /// process.
    /// @dev Required state: Operational Normal
    /// @dev State transition: -> Operational Migration
    /// @param _agent The address of the MigrationAgent contract
    function setMigrationAgent(address _agent) public {
        // Abort if not in Operational Normal state.
        require(funding == false);
        require(msg.sender == migrationMaster);
        migrationAgent = _agent;
    }

    function setMigrationMaster(address _master) public {
        require(msg.sender == migrationMaster);
        require(_master != 0);
        migrationMaster = _master;
    }

    // Crowdfunding:
    /// @notice Create tokens when funding is active.
    /// @dev Required state: Funding Active
    /// @dev State transition: -> Funding Success (only if cap reached)
    function create() public payable {
        // Abort if not in Funding Active state.
        // The checks are split (instead of using or operator) because it is
        // cheaper this way.
        require(funding == true);
        require(block.number >= startBlock);
        require(block.number <= endBlock);

        // Do not allow creating 0 or more than the cap tokens.
        require(msg.value != 0);
        require(msg.value <= (CREATION_CAP - totalXIN) / CREATION_RATE);

        uint numTokens = msg.value * CREATION_RATE;
        totalXIN += numTokens;

        // Assign new tokens to the sender
        balances[msg.sender] += numTokens;

        // Log token creation event
        Transfer(0, msg.sender, numTokens);
    }

    /// @notice Finalize crowdfunding
    /// @dev If cap was reached or crowdfunding has ended then:
    /// create XIN,
    /// @dev Required state: Funding Success
    /// @dev State transition: -> Operational Normal
    function finalize() public {
        // Abort if not in Funding Success state.

        require(funding == true);
        require((block.number <= endBlock || totalXIN < CREATION_MIN) && totalXIN < CREATION_CAP);

        // Switch to Operational state. This is the only place this can happen.
        funding = false;

        // Create additional GNT for the Golem Factory and developers as
        // the 18% of total number of tokens.
        // All additional tokens are transfered to the account controller by
        // GNTAllocation contract which will not allow using them for 6 months.
        uint percentOfTotal = 18;
        uint additionalTokens;

        additionalTokens = totalXIN * percentOfTotal / (100 - percentOfTotal);
        totalXIN += additionalTokens;

        // Transfer ETH to the Golem Factory address.
        xinHome.transfer(this.balance);
    }

    /// @notice Get back the ether sent during the funding in case the funding
    /// has not reached the minimum level.
    /// @dev Required state: Funding Failure
    function refundXIN() public {
        // Abort if not in Funding Failure state.
        require(funding == false);
        require(block.number > endBlock);
        require(totalXIN < CREATION_MIN);

        uint xinValue = balances[msg.sender];
        require(xinValue == 0);
        balances[msg.sender] = 0;
        totalXIN -= xinValue;

        uint ethValue = xinValue / CREATION_RATE;
        Refund(msg.sender, ethValue);
        msg.sender.transfer(ethValue);
    }
}


contract XINAllocation {
    // Total number of allocations to distribute additional tokens among
    // developers and the xinHome.
    uint public constant TOTAL_ALLOCATIONS = 30000;

    // Addresses of developer and the Golem Factory to allocations mapping.
    mapping (address => uint) public allocations;

    XInsight public xin;
    uint public  unlockedAt;

    uint public tokensCreated = 0;

    function XINAllocation(address xinHome) internal {
        xin = XInsight(msg.sender);
        //unlockedAt = now + 6 * 30 days;
        allocations[xinHome] = 20000; // 12/18 pp of 30000 allocations.

        // For developers:
        allocations[0x00b3C985d5051e91B2ebA6D7D103ADeD6c9a1119] = 2500; //
        allocations[0xF98abd01EDd7BE82704c0179C457Ef4E96F66EE8] = 730; //
    }
}
