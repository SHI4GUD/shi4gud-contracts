// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
// import "hardhat/console.sol";

interface TPI {
    function price(address poolAddr) external view returns (uint);
    function priceV2(address pairAddr) external view returns (uint256);
}

contract Ktv2 is Ownable {
    event Staked(address, uint);
    event Withdrew(address, uint);
    event Gave(address, uint);
    event Rwd(address, uint);
    event Voted(uint, address, string);

    IERC20 token;
    address public tokenAddr;
    address payable public dest;

    address public burnDest;
    address public pool;
    bool public v2;

    TPI public tp;

    mapping(address => uint) public userStks;
    mapping(address => bool) public declines;

    uint public totalStk;
    uint public totalGvn;
    uint public totalBurned;
    uint16 public maxBrnPrc = 20;
    uint16 public donationPrc = 500;
    uint16 public burnFactor = 20;

    uint16 internal constant P_FCTR = 10;
    uint32 internal constant P_DEN = 100 * P_FCTR;

    uint public startBlock;
    uint16 public epochInterval = 44444;
    uint16 public consensusReq = 1;
    uint16 public ocFee = 2 * P_FCTR;

    // block => address => cnt
    mapping(uint => mapping(address => uint16)) public blockRwd;
    // ocRwdr => block => destVoted
    mapping(address => mapping(uint => address)) public ocRwdrVote;

    mapping(address => bool) public ocRwdrs;
    mapping(address => mapping(uint => uint)) public ocFees;
    uint public tlOcFees;

    // ------------------------------------------------------------------------
    // OC Management
    uint16 public totalOC = 1;
    // newOC => vote count
    mapping(address => uint16) public addVotes;
    // existingOC => vote count
    mapping(address => uint16) public removeVotes;
    // voter => target => voted for add
    mapping(address => mapping(address => bool)) public hasVotedAdd;
    // voter => target => voted for remove
    mapping(address => mapping(address => bool)) public hasVotedRemove;
    mapping(address => uint) public pastOcFees;
    mapping(address => uint) public lastStartBlock;

    // OC Management Events
    event VotedToAdd(address indexed voter, address indexed newOC, string data);
    event VotedToRemove(address indexed voter, address indexed existingOC, string data);
    event NodeAdded(address indexed newOC);
    event NodeRemoved(address indexed oldOC);

    /** -----------------------------------------------------------------------
     *
     */
    constructor(
        address _burnDest,
        address _token,
        address payable _dest,
        address _pool,
        address _ocPrcAddr,
        address _tp,
        bool _v2
    ) Ownable() {
        burnDest = _burnDest;
        tokenAddr = _token;
        token = IERC20(_token);
        dest = _dest;
        tp = TPI(_tp);
        startBlock = block.number;
        v2 = _v2;

        ocRwdrs[_ocPrcAddr] = true;
        setPool(_pool);
    }

    receive() external payable {}

    /** -----------------------------------------------------------------------
     * 
     */
    function rwd(address payable _to, uint _amt) external onlyOC notDeclined(_to) epochComplete migrateFees {
        require(blockRwd[startBlock][_to] >= consensusReq, "No consensus");

        uint fee = recordOCFee();
        uint _rwd = _amt > fee ? _amt - fee : 0;
        startBlock = startBlock + epochInterval;

        if(_rwd > P_DEN) {
            (bool sent, ) = _to.call{value: _rwd}("");
            require(sent, "Transfer failed");
        }

        emit Rwd(_to, _rwd);
    }


    /** -----------------------------------------------------------------------
     *
     */
    function vote(address payable _to, string calldata data) external onlyOC notDeclined(_to) epochComplete migrateFees {
        require(ocRwdrVote[msg.sender][startBlock] == address(0), "Already voted");

        blockRwd[startBlock][_to]++;
        ocRwdrVote[msg.sender][startBlock] = _to;

        recordOCFee();

        emit Voted(startBlock, _to, data);
    }

    /** -----------------------------------------------------------------------
     *
     */
    function resetVote(address _to) external onlyOC notDeclined(_to) epochComplete migrateFees {
        require(blockRwd[startBlock][_to] > 0, "Invalid dest");
        require(ocRwdrVote[msg.sender][startBlock] != address(0), "Vote missing");

        blockRwd[startBlock][_to]--;
        ocRwdrVote[msg.sender][startBlock] = address(0);
        resetOCFee();

        emit Voted(startBlock, _to, "rst");
    }

    /** -----------------------------------------------------------------------
     * 
     */
    function resetOCFee() private {
        tlOcFees -= ocFees[msg.sender][startBlock];
        ocFees[msg.sender][startBlock] = 0;
    }

    /** -----------------------------------------------------------------------
     * 
     */
    function recordOCFee() private returns (uint) {
        uint incrAmt = 0;
        if (address(this).balance > tlOcFees) {
            incrAmt = ((address(this).balance - tlOcFees) * ocFee) / P_DEN;
            ocFees[msg.sender][startBlock] += incrAmt;
            tlOcFees += incrAmt;
        }
        return incrAmt;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function withdrawOCFee() external migrateFees {
        uint amt = pastOcFees[msg.sender];
        if (block.number > startBlock + epochInterval) {  // Epoch complete
            uint currentFee = ocFees[msg.sender][startBlock];
            if (currentFee > 0) {
                amt += currentFee;
                ocFees[msg.sender][startBlock] = 0;
            }
        }

        pastOcFees[msg.sender] = 0;
        tlOcFees -= amt;
        if (address(this).balance >= amt) {
            (bool sent, ) = msg.sender.call{value: amt}("");
            require(sent, "Failed");
        }
    }

    /** -----------------------------------------------------------------------
     *
     */
    modifier migrateFees() {
        if (lastStartBlock[msg.sender] != startBlock && lastStartBlock[msg.sender] != 0) {
            uint oldBlock = lastStartBlock[msg.sender];
            uint oldFee = ocFees[msg.sender][oldBlock];
            if (oldFee > 0 && oldBlock < startBlock) {
                pastOcFees[msg.sender] += oldFee;
                ocFees[msg.sender][oldBlock] = 0;  // Clean up
            }
        }
        lastStartBlock[msg.sender] = startBlock;
        _;
    }

    /** -----------------------------------------------------------------------
     *
     */
    modifier epochComplete() {
        require(block.number > startBlock + epochInterval, "Epoch incomplete");
        _;
    }


    /** -----------------------------------------------------------------------
     *
     */
    modifier onlyOC() {
        require(ocRwdrs[msg.sender], "Not authorized");
        _;
    }

    /** -----------------------------------------------------------------------
     *
     */
    modifier notDeclined(address _to) {
        require(!declines[_to], "Declined");
        _;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setEpochInterval(uint16 interval) public onlyOwner {
        epochInterval = interval;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setConsensusReq(uint16 req) public onlyOwner {
        consensusReq = req;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setOCFee(uint16 fee) public onlyOwner {
        ocFee = fee;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function addOCRwdr(address addr) public onlyOwner {
        require(!ocRwdrs[addr], 'Already set');
        ocRwdrs[addr] = true;
        totalOC++;
        consensusReq = (totalOC + 1) / 2;
        emit NodeAdded(addr);
    }

    /** -----------------------------------------------------------------------
     *
     */
    function removeOCRwdr(address addr) public onlyOwner {
        require(ocRwdrs[addr], 'Already removed');
        if (totalOC > 1) {
            ocRwdrs[addr] = false;
            totalOC--;
            consensusReq = (totalOC + 1) / 2;
            emit NodeRemoved(addr);
        }
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setDest(address addr) public onlyOwner {
        dest = payable(addr);
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setMaxBurnPrc(uint16 amt) public onlyOwner {
        require(amt < 50 * P_FCTR, "Max burn prc >= 50%");
        maxBrnPrc = amt;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setBurnFactor(uint16 amt) public onlyOwner {
        require(amt < 50 * P_FCTR, "Burn factor >= 50%");
        burnFactor = amt;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setDonationPrc(uint16 amt) public onlyOwner {
        require(amt <= 100 * P_FCTR, "Donation prc > 100%");
        donationPrc = amt;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setV2(bool _v2) public onlyOwner {
        require(v2 != _v2, "Same value");
        v2 = _v2;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function getTokenPrice() private view returns (uint) {
        
        if (v2) {
            return tp.priceV2(pool);
        }
        else {
            return tp.price(pool);
        }
    }

    /** -----------------------------------------------------------------------
     *
     */
    function setPool(address _pool) public onlyOwner {
        pool = _pool;
        uint price = getTokenPrice();       
        require(price > 0);
    }

    /** -----------------------------------------------------------------------
     *
     */
    function decline() public {
        declines[msg.sender] = true;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function allow() public {
        declines[msg.sender] = false;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function voteToAdd(address newOC, string calldata data) external onlyOC {
        require(!hasVotedAdd[msg.sender][newOC], "Already voted for this add");
        require(!ocRwdrs[newOC], "Already an OC node");
        addVotes[newOC]++;
        hasVotedAdd[msg.sender][newOC] = true;
        emit VotedToAdd(msg.sender, newOC, data);
        
        uint16 required = (totalOC + 1) / 2;
        if (addVotes[newOC] >= required) {
            ocRwdrs[newOC] = true;
            totalOC++;
            consensusReq = (totalOC + 1) / 2;
            emit NodeAdded(newOC);
        }
    }

    /** -----------------------------------------------------------------------
     * 
     */
    function voteToRemove(address existingOC, string calldata data) external onlyOC {
        require(!hasVotedRemove[msg.sender][existingOC], "Already voted for this remove");
        require(ocRwdrs[existingOC], "Not an OC node");
        removeVotes[existingOC]++;
        hasVotedRemove[msg.sender][existingOC] = true;
        emit VotedToRemove(msg.sender, existingOC, data);
        
        uint16 required = (totalOC + 1) / 2;
        if (removeVotes[existingOC] >= required && totalOC > 1) {
            ocRwdrs[existingOC] = false;
            totalOC--;
            consensusReq = (totalOC + 1) / 2;
            emit NodeRemoved(existingOC);
        }
    }

    /** -----------------------------------------------------------------------
     *
     */
    function resetVoteToAdd(address newOC) external onlyOC {
        require(hasVotedAdd[msg.sender][newOC], "No add vote to reset for this target");
        addVotes[newOC]--;
        hasVotedAdd[msg.sender][newOC] = false;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function resetVoteToRemove(address existingOC) external onlyOC {
        require(hasVotedRemove[msg.sender][existingOC], "No remove vote to reset for this target");
        removeVotes[existingOC]--;
        hasVotedRemove[msg.sender][existingOC] = false;
    }

    /** -----------------------------------------------------------------------
     *
     */
    function stake(uint256 amt) external {
        require(amt > 0, "Amount must be greater than 0");

        userStks[msg.sender] += amt;
        totalStk += amt;

        require(token.transferFrom(msg.sender, address(this), amt), "Transfer failed");

        emit Staked(msg.sender, amt);
    }


    /** -----------------------------------------------------------------------
     *
     */
    function withdraw(uint amt) external {
        require(amt <= userStks[msg.sender] && amt <= totalStk, "Exceeds balance");

        userStks[msg.sender] -= amt;
        totalStk -= amt;

        require(token.transfer(msg.sender, amt), "Transfer failed");
        emit Withdrew(msg.sender, amt);
    }

    /** -----------------------------------------------------------------------
     * @dev Allows users to give funds to the contract.
     */
    function give() external payable {
        uint giveAmt = (msg.value * donationPrc) / P_DEN;
        totalGvn += giveAmt;

        uint tknPrice = getTokenPrice();
        uint tknAmtGvn = (msg.value * 10**18) / tknPrice;
        uint maxBrn = totalStk;

        if (totalStk > P_DEN * 10) {
            maxBrn = (totalStk * maxBrnPrc) / P_DEN;
        }

        uint burnAmt = maxBrn;

        // Mulitply by P_FCTR because burnFactor has P_FCTR built in
        if (tknAmtGvn < (maxBrn * P_FCTR) / (2*burnFactor)) {
            burnAmt = (tknAmtGvn * burnFactor) / P_FCTR;

        } else if (tknAmtGvn < (maxBrn * P_FCTR) / burnFactor) {
            burnAmt = ((tknAmtGvn * burnFactor) / (P_FCTR * 2)) + (maxBrn / 4);

        } else if (tknAmtGvn < maxBrn) {
            burnAmt = ((tknAmtGvn * burnFactor) / (P_FCTR * 4)) + (maxBrn / 2);
        }

        if (burnAmt > 0 && totalStk >= burnAmt) {
            totalStk -= burnAmt;
            totalBurned += burnAmt;
            require(token.transfer(burnDest, burnAmt), "Burn failed");
        }

        // Donate
        (bool sent, ) = dest.call{value: giveAmt}("");
        require(sent, "Donate failed");

        emit Gave(msg.sender, giveAmt);
    }

    /** -----------------------------------------------------------------------
     *
     */
    function withdrawTkn(address _to, address addr) external onlyOwner {
        require(addr != tokenAddr, "Forbidden");

        IERC20 tkn = IERC20(addr);
        require(
            tkn.transfer(_to, tkn.balanceOf(address(this))),
            "Failed"
        );
    }
}