// test/Galanthus.test.js
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Galanthus Contract', () => {
    let Galanthus;
    let galanthus;
    let owner;
    let donor1;
    let donor2;
    let reliefPartner1;
    let reliefPartner2;
    let urgentAidPartner;

    const INITIAL_SUPPLY = 1000000; // of GAL token

    beforeEach(async () => {
        [owner, donor1, donor2, reliefPartner1, reliefPartner2, urgentAidPartner] = await ethers.getSigners();

        const GalanthusFactory = await ethers.getContractFactory('Galanthus');
        galanthus = await GalanthusFactory.deploy(INITIAL_SUPPLY);

        expect(await galanthus.name()).to.equal('Galanthus');
        expect(await galanthus.symbol()).to.equal('GAL');
        expect(await galanthus.totalSupply()).to.equal(INITIAL_SUPPLY);
    });

    describe('Token Basic Functionality', () => {
        it('should transfer tokens correctly', async () => {
            const transferAmount = 10;
            await galanthus.transfer(donor1.address, transferAmount);

            expect(await galanthus.balanceOf(donor1.address)).to.equal(transferAmount);
            expect(await galanthus.balanceOf(owner.address)).to.equal(INITIAL_SUPPLY - transferAmount);
        });

        it('should not allow transfer to zero address', async () => {
            await expect(
                galanthus.transfer(ethers.ZeroAddress, 100)
            ).to.be.revertedWith('Transfer to the zero address');
        });

        it('should not allow transfer of more tokens than balance', async () => {
            await expect(
                galanthus.connect(donor1).transfer(owner.address, 1)
            ).to.be.revertedWith('Insufficient balance');
        });
    });

    describe('Approval and TransferFrom', () => {
        it('should approve tokens for spending', async () => {
            const approveAmount = 100;
            await galanthus.approve(donor1.address, approveAmount);

            expect(await galanthus.allowance(owner.address, donor1.address)).to.equal(approveAmount);
        });

        it('should transfer tokens via transferFrom', async () => {
            const transferAmount = 100;
            await galanthus.transfer(donor1.address, transferAmount);

            await galanthus.connect(donor1).approve(owner.address, transferAmount);
            await galanthus.transferFrom(donor1.address, donor2.address, transferAmount);

            expect(await galanthus.balanceOf(donor2.address)).to.equal(transferAmount);
        });

        it('should not allow transferFrom beyond allowance', async () => {
            const transferAmount = 100;
            await galanthus.transfer(donor1.address, transferAmount);

            await galanthus.connect(donor1).approve(owner.address, transferAmount / 2);

            await expect(
                galanthus.transferFrom(donor1.address, donor2.address, transferAmount)
            ).to.be.revertedWith('Allowance exceeded');
        });
    });

    describe('Verified Donors Management', () => {
        it('should add verified donors by fund manager', async () => {
            await galanthus.addVerifiedDonor(donor1.address);

            expect(await galanthus.getLastVerifiedDonor()).to.equal(donor1.address);
        });

        it('should not allow non-fund manager to add verified donors', async () => {
            await expect(
                galanthus.connect(donor1).addVerifiedDonor(donor2.address)
            ).to.be.revertedWith('Only fund manager can add verified donors');
        });

        it('should remove verified donors', async () => {
            await galanthus.addVerifiedDonor(donor1.address);
            await galanthus.addVerifiedDonor(donor2.address);

            await galanthus.removeVerifiedDonor(donor1.address);

            expect(
                await galanthus.getLastVerifiedDonor()
            ).to.equal(donor2.address);
        });
    });

    describe('Verified Relief Partners Management', () => {
        it('should add verified relief partners', async () => {
            await galanthus.addVerifiedReliefPartner(reliefPartner1.address);

            expect(await galanthus.getLastVerifiedReliefPartner()).to.equal(reliefPartner1.address);
        });

        it('should not allow non-fund manager to add relief partners', async () => {
            await expect(
                galanthus.connect(donor1).addVerifiedReliefPartner(reliefPartner1.address)
            ).to.be.revertedWith('Only fund manager can add verified relief partners');
        });

        it('should remove verified relief partners', async () => {
            await galanthus.addVerifiedReliefPartner(reliefPartner1.address);
            await galanthus.addVerifiedReliefPartner(reliefPartner2.address);

            await galanthus.removeVerifiedReliefPartner(reliefPartner1.address);

            expect(await galanthus.getLastVerifiedReliefPartner()).to.equal(reliefPartner2.address);
        });
    });

    describe('Urgent Aid Partner Management', () => {
        it('should set urgent aid partner by fund manager', async () => {
            await galanthus.setUrgentAidPartner(urgentAidPartner.address);
        });

        it('should not allow non-fund manager to set urgent aid partner', async () => {
            await expect(
                galanthus.connect(donor1).setUrgentAidPartner(urgentAidPartner.address)
            ).to.be.revertedWith('Only fund manager can set urgent aid partner for this contract');
        });
    });

    describe('Donation Mechanism', () => {
        it("should be able to donate and receive tokens in exchange", async function () {
            await galanthus.setUrgentAidPartner(urgentAidPartner)

            const uapWeiBalanceBefore = await ethers.provider.getBalance(urgentAidPartner.address);

            const donationAmount = 507360000; 
            await galanthus.connect(donor1).donate({ value: donationAmount })
            expect(await galanthus.balanceOf(donor1)).to.equal(9950) // 1 out of 10 is our fee

            const uapWeiBalanceAfter = await ethers.provider.getBalance(urgentAidPartner.address);
            const contractWeiBalanceAfter = await ethers.provider.getBalance(galanthus.target);

            expect(uapWeiBalanceAfter - uapWeiBalanceBefore + contractWeiBalanceAfter).to.equal(donationAmount)
        });

        it('should process donations correctly', async () => {
            await galanthus.setUrgentAidPartner(urgentAidPartner.address);

            const donationAmount = 60200;

            await galanthus.addVerifiedDonor(donor1.address);

            await galanthus.connect(donor1).donate({ value: donationAmount });
        });

        it('should calculate fund running budget correctly', async () => {
            await galanthus.setUrgentAidPartner(urgentAidPartner.address);
            await galanthus.addVerifiedDonor(donor1.address);

            const donationAmount = 60200;
            await galanthus.connect(donor1).donate({ value: donationAmount });

            const expectedFundRunningBudget = donationAmount * 5 / 1000; // 0.5% of donation
            expect(await galanthus.fundRunningBudget()).to.equal(expectedFundRunningBudget);
        });
    });

    describe('Proposals and Voting', () => {
        beforeEach(async () => {
            // Prepare for proposal tests
            await galanthus.addVerifiedReliefPartner(reliefPartner1.address);
            await galanthus.addVerifiedDonor(donor1.address);
            await galanthus.transfer(donor1.address, 130);
        });

        it('should publish proposal by verified relief partner', async () => {
            await galanthus.connect(reliefPartner1).publishProposal(
                'Test Proposal',
                'Description of test proposal'
            );

            const proposalCount = await galanthus.proposalCount();
            const proposal = await galanthus.getProposalDetails(proposalCount);

            expect(proposal.proposer).to.equal(reliefPartner1.address);
            expect(proposal.title).to.equal('Test Proposal');
        });

        it('should not allow non-verified partners to publish proposals', async () => {
            await expect(
                galanthus.connect(donor1).publishProposal('Unauthorized', 'Test')
            ).to.be.revertedWith('Only verified relief partners can create proposals');
        });

        it('should allow verified donors to vote on proposals', async () => {
            await galanthus.connect(reliefPartner1).publishProposal(
                'Voting Test Proposal',
                'Description of voting test proposal'
            );

            const proposalCount = await galanthus.proposalCount();

            await galanthus.connect(donor1).voteOnProposal(proposalCount);

            const proposalDetails = await galanthus.getProposalDetails(proposalCount);
            expect(proposalDetails.votesFor).to.be.gt(0);
        });

        it('should not allow double voting', async () => {
            await galanthus.connect(reliefPartner1).publishProposal(
                'Double Vote Test',
                'Testing double vote prevention'
            );

            const proposalCount = await galanthus.proposalCount();

            await galanthus.connect(donor1).voteOnProposal(proposalCount);

            await expect(
                galanthus.connect(donor1).voteOnProposal(proposalCount)
            ).to.be.revertedWith('Donor has already voted on this proposal');
        });
    });

    describe('Token Burning', () => {
        it('should burn tokens by owner', async () => {
            const burnAmount = 20;

            await galanthus.transfer(donor1.address, burnAmount);
            await galanthus.connect(donor1).burnTokens(donor1.address, burnAmount);

            expect(await galanthus.balanceOf(donor1.address)).to.equal(0);
            expect(await galanthus.totalSupply()).to.equal(INITIAL_SUPPLY - burnAmount);
        });
    });

    describe('Quadratic Voting Calculations', () => {
        it("should determine correct number for quadratic voting of votes given a balance of GAL tokens", async function () {
            expect(await galanthus.quadraticNumberOfVotes(100)).to.equal(6);
            expect(await galanthus.quadraticNumberOfVotes(10)).to.equal(2);
            expect(await galanthus.quadraticNumberOfVotes(1)).to.equal(1);
        })

        it('should calculate quadratic cost of votes correctly', async () => {
            const votes = 15;
            const cost = await galanthus.quadraticCostOfVotes(votes);
            expect(cost).to.equal((votes * (votes + 1) * (2 * votes + 1)) / 6);
        });
    });
});
