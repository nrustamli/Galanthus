// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
    uint256 public proposalsBudget; // an amount that gets accummulated after we reach the urgent aid threshold 
    uint256 public fundRunningBudget; // total of fees charged from all transactions to accummulate money for operating the fund

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
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
}
