// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";

contract Galanthus {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    address fundManager;
    address urgentAidPartner;
    address[] verifiedDonors;
    address[] verifiedReliefPartners;


    uint256 public urgentAidDueAmount; // a threshold before which all funds are directed to urgent aid partner
    uint256 public proposalsBudget; // an amount that gets accumulated after we reach the urgent aid threshold 
    uint256 public fundRunningBudget; // total of fees charged from all transactions to accumulate money for operating the fund

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 votesFor;
        bool executed;
        bool passed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    mapping(uint256 => mapping(address => bool)) public hasVoted; 

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TokensBurned(address indexed burner, uint256 amount);

    event DonationReceived(address indexed donor, uint256 value);
    event VerifiedDonorRegistered(address indexed donor);
    event VerifiedDonorRemoved(address indexed donor);
    event VerifiedReliefPartnerRegistered(address indexed reliefPartner);
    event VerifiedReliefPartnerRemoved(address indexed reliefPartner);
    event UrgentAidPartnerWasSet(address indexed urgentAidPartner);
    event FundRunningFeeCharged(address indexed donor, uint256 value);

    event ProposalsBudgetIncreased(uint256 value);
    event UrgentAidDueAmountDecreased(uint256 value);
    event FundsTransferredToUrgentAidPartner(uint256 value);
    event FundsTransferredToReliefPartner(address indexed reliefPartner, uint256 value);

    event ProposalPublished(uint256 indexed proposalId, address indexed proposer, string title);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event ProposalPassed(uint256 indexed proposalId);

    constructor(
        uint256 _initialSupply
    ) {
        name = "Galanthus";
        symbol = "GAL";
        totalSupply = _initialSupply;
        balances[msg.sender] = totalSupply;
        fundManager = msg.sender; 
        urgentAidDueAmount = 50736 * 100000; // roughly ~~ $100K
        proposalsBudget = 0;

        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function donate() public payable {
        emit DonationReceived(msg.sender, msg.value);

        uint256 fundFee = msg.value * 5 / 1000; // we charge 0.5%     
        uint256 donationAmount = msg.value - fundFee;   

        uint256 tokensToIssue = donationAmount / 50736;
        require(tokensToIssue > 0, "Donation amount is too small to issue tokens");
        require(balances[fundManager] >= tokensToIssue, "Insufficient tokens in contract");

        balances[fundManager] -= tokensToIssue;
        balances[msg.sender] += tokensToIssue;

        emit DonationReceived(msg.sender, msg.value);
        emit Transfer(fundManager, msg.sender, tokensToIssue);

        fundRunningBudget += fundFee;
        emit FundRunningFeeCharged(msg.sender, fundFee);

        if (urgentAidDueAmount == 0) {
            // beyond urgent aid partner (UAP) threshold 
            proposalsBudget += donationAmount;
            emit ProposalsBudgetIncreased(donationAmount);
        } else if (donationAmount > urgentAidDueAmount) {
            // urgent aid partner (UAP) threshold is not reached yet but donated amount is more than what's remaining there
            proposalsBudget += donationAmount - urgentAidDueAmount;
            uint256 lastRemainingDueAmount = urgentAidDueAmount;
            urgentAidDueAmount = 0;
            emit ProposalsBudgetIncreased(donationAmount - urgentAidDueAmount);
            emit UrgentAidDueAmountDecreased(lastRemainingDueAmount);
            sendAmountToUrgentAidPartner(lastRemainingDueAmount);
        } else {
            // urgent aid partner (UAP) threshold is not reached yet
            urgentAidDueAmount -= donationAmount;
            emit UrgentAidDueAmountDecreased(donationAmount);
            sendAmountToUrgentAidPartner(donationAmount);
        }
    }

    function sendAmountToUrgentAidPartner(uint256 amount) public payable  {
        payable(urgentAidPartner).transfer(amount);
        emit FundsTransferredToUrgentAidPartner(amount);
    }

    function sendAmountToReliefPartner(address reliefPartner, uint256 amount) public payable  {
        payable(reliefPartner).transfer(amount);
        emit FundsTransferredToReliefPartner(reliefPartner, amount);
    }

    function addVerifiedDonor(address newDonor) public {
        require(msg.sender == fundManager, "Only fund manager can add verified donors");
        verifiedDonors.push(newDonor);
        emit VerifiedDonorRegistered(newDonor);
    }

    function getLastVerifiedDonor() public view returns (address) {
        return verifiedDonors[verifiedDonors.length - 1];
    }

    function removeVerifiedDonor(address donor) public {
        require(msg.sender == fundManager, "Only fund manager can remove verified donors");

        bool found = false;
        for (uint i = 0; i < verifiedDonors.length; i++) {
            if (verifiedDonors[i] == donor) {
                found = true;

                for (uint j = i; j < verifiedDonors.length - 1; j++) {
                    verifiedDonors[j] = verifiedDonors[j + 1];
                }

                verifiedDonors.pop();
                break;
            }
        }

        require(found, "Donor not found in the verified donors list");
        emit VerifiedDonorRemoved(donor);
    }


    function addVerifiedReliefPartner(address newReliefPartner) public {
        require(msg.sender == fundManager, "Only fund manager can add verified relief partners");
        verifiedReliefPartners.push(newReliefPartner);
        emit VerifiedReliefPartnerRegistered(newReliefPartner);
    }

    function getLastVerifiedReliefPartner() public view returns (address) {
        return verifiedReliefPartners[verifiedReliefPartners.length - 1];
    }

    function removeVerifiedReliefPartner(address reliefPartner) public {
        require(msg.sender == fundManager, "Only fund manager can remove verified relief partners");

        bool found = false;
        for (uint i = 0; i < verifiedReliefPartners.length; i++) {
            if (verifiedReliefPartners[i] == reliefPartner) {
                found = true;

                for (uint j = i; j < verifiedReliefPartners.length - 1; j++) {
                    verifiedReliefPartners[j] = verifiedReliefPartners[j + 1];
                }

                verifiedReliefPartners.pop();
                break;
            }
        }

        require(found, "Relief partner not found in the verified relief partners list");
        emit VerifiedReliefPartnerRemoved(reliefPartner);
    }



    function setUrgentAidPartner(address _urgentAidPartner) public {
        require(msg.sender == fundManager, "Only fund manager can set urgent aid partner for this contract");
        urgentAidPartner = _urgentAidPartner;
        emit UrgentAidPartnerWasSet(urgentAidPartner);
    }

    // proposals and voting

    function publishProposal(string memory _title, string memory _description) public {
        bool isVerifiedPartner = false;
        for (uint i = 0; i < verifiedReliefPartners.length; i++) {
            if (verifiedReliefPartners[i] == msg.sender) {
                isVerifiedPartner = true;
                break;
            }
        }
        require(isVerifiedPartner, "Only verified relief partners can create proposals");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            title: _title,
            description: _description,
            votesFor: 0,
            executed: false,
            passed: false
        });

        emit ProposalPublished(proposalCount, msg.sender, _title);
    }

    function quadraticNumberOfVotes(uint256 balance) public pure returns (uint256) {
        uint256 remainingBalance = balance;
        uint256 votes = 0;

        for (uint i = 0; remainingBalance >= i*i; i++) {
            votes = i;
            remainingBalance -= i*i;
        }
        
        return votes;
    }

    function quadraticCostOfVotes(uint256 n) public pure returns (uint256) {
        // Mathematical formula - sum of squares 
        return (n * (n + 1) * (2 * n + 1)) / 6;
    }

    function voteOnProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(!hasVoted[_proposalId][msg.sender], "Donor has already voted on this proposal");

        bool isVerifiedDonor = false;
        for (uint i = 0; i < verifiedDonors.length; i++) {
            if (verifiedDonors[i] == msg.sender) {
                isVerifiedDonor = true;
                break;
            }
        }
        require(isVerifiedDonor, "Only verified donors can vote");

        uint256 voterBalance = balanceOf(msg.sender);
        require(voterBalance > 0, "Insufficient tokens to vote");

        hasVoted[_proposalId][msg.sender] = true;
        
        uint256 votes = quadraticNumberOfVotes(voterBalance);
        proposal.votesFor += votes;

        burnTokens(msg.sender, quadraticCostOfVotes(votes)); // burn tokens equal the cost of voting 

        emit ProposalVoted(_proposalId, msg.sender, votes);
    }

    function getProposalDetails(uint256 _proposalId) public view returns (address proposer, 
        string memory title, string memory description, uint256 votesFor, bool executed, bool passed) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.title,
            proposal.description,
            proposal.votesFor,
            proposal.executed,
            proposal.passed
        );
    }


    function executeProposals() public {
        require(msg.sender == fundManager, "Only fund manager can execute proposals");
        require(proposalsBudget > 0, "No funds available in the proposal budget");

        uint256 maxVotes = 0;
        uint256 winningProposalId = 0;
        uint256 tieCheckVotes = 0;

        for (uint256 i = 1; i <= proposalCount; i++) {
            Proposal storage proposal = proposals[i];
            
            if (!proposal.executed) {                
                if (proposal.votesFor > maxVotes) {
                    maxVotes = proposal.votesFor;
                    winningProposalId = i;
                    tieCheckVotes = 0; 
                } else if (proposal.votesFor == maxVotes && maxVotes > 0) {
                    tieCheckVotes++; 
                }
            }
        }

        require(tieCheckVotes == 0, "Multiple proposals have maximum votes - cannot determine single winner");
        require(winningProposalId > 0, "No executable proposals found");

        Proposal storage winningProposal = proposals[winningProposalId];
        
        proposalsBudget = 0;
        sendAmountToReliefPartner(winningProposal.proposer, proposalsBudget);
    
        winningProposal.passed = true;
        emit ProposalPassed(winningProposal.id);
        
        for (uint256 i = 1; i <= proposalCount; i++) {
            Proposal storage proposal = proposals[i];
            proposal.executed = true;
            emit ProposalExecuted(i, proposal.passed);
        }
    }
    // end of proposals and voting

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(recipient != address(0), "Transfer to the zero address");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    } 

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "Approve to the zero address");

        allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(balances[sender] >= amount, "Insufficient balance");
        require(allowances[sender][msg.sender] >= amount, "Allowance exceeded");

        balances[sender] -= amount;
        balances[recipient] += amount;
        allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function burnTokens(address account, uint256 amount) public {
        require(balances[account] >= amount, "Insufficient balance to burn");
        require(msg.sender == account, "Only account owner can burn GAL tokens in exchange for votes");
        
        balances[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
        emit TokensBurned(account, amount);
    }
}
