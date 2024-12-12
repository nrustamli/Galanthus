const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Galanthus", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployGalanthusFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount, donor1, donor2, donor3, urgentAidPartner, 
      charityLongTerm1, charityLongTerm2, charityLongTerm3] = await ethers.getSigners();

    const initialSupply = 1000000;

    const Galanthus = await ethers.getContractFactory("Galanthus");
    const galanthus = await Galanthus.deploy(initialSupply);
    await galanthus.waitForDeployment();

    return {
      galanthus, initialSupply, owner, otherAccount, donor1, donor2, donor3, urgentAidPartner,
      charityLongTerm1, charityLongTerm2, charityLongTerm3
    };
  }

  describe("ERC-20", function () {
    it("Should set the right initialSupply", async function () {
      const { galanthus, initialSupply } = await loadFixture(deployGalanthusFixture);
      expect(await galanthus.totalSupply()).to.equal(initialSupply);
    });

    it("Should should transfer the right amount", async function () {
      const { galanthus, otherAccount } = await loadFixture(deployGalanthusFixture);
      await galanthus.transfer(otherAccount, 40000)
      expect(await galanthus.balanceOf(otherAccount)).to.equal(40000);
    });
  });

  describe("Fund Contract", function () {
    describe("Donors", function () {
      it("Fund managers should be able to register verified donors", async function () {
        const { galanthus, donor1 } = await loadFixture(deployGalanthusFixture);

        const tx = await galanthus.addVerifiedDonor(donor1)
        await tx.wait()

        const lastVerifiedAddress = await galanthus.getLastVerifiedDonor()
        expect(lastVerifiedAddress).to.equal(donor1)
      });

      it("Non fund managers should not be able to register verified donors", async function () {
        const { galanthus, donor1 } = await loadFixture(deployGalanthusFixture);

        await expect(galanthus.connect(donor1).addVerifiedDonor(donor1)).to.be
          .revertedWith("Only fund manager can add verified donors")
      });

      it("Fund managers should be able to remove verified donors", async function () {
        const { galanthus, donor1, donor2 } = await loadFixture(deployGalanthusFixture);

        await galanthus.addVerifiedDonor(donor1)
        await galanthus.addVerifiedDonor(donor2)
        
        expect(await galanthus.getLastVerifiedDonor()).to.equal(donor2)

        await galanthus.removeVerifiedDonor(donor2)
        expect(await galanthus.getLastVerifiedDonor()).to.equal(donor1)
      });

      it("Donors should be able to donate and receive tokens in exchange", async function () {
        const { galanthus, donor1, urgentAidPartner } = await loadFixture(deployGalanthusFixture);
        await galanthus.setUrgentAidPartner(urgentAidPartner)

        const uapWeiBalanceBefore = await ethers.provider.getBalance(urgentAidPartner.address);

        const donationAmount = 507360000; // this is in wei ~~ roughly 10$ equivalent
        await galanthus.connect(donor1).donate({ value: donationAmount })
        expect(await galanthus.balanceOf(donor1)).to.equal(9950) // 1 out of 10 is our fee

        const uapWeiBalanceAfter = await ethers.provider.getBalance(urgentAidPartner.address);
        const contractWeiBalanceAfter = await ethers.provider.getBalance(galanthus.target);
        
        expect(uapWeiBalanceAfter - uapWeiBalanceBefore + contractWeiBalanceAfter).to.equal(donationAmount)
      });
    })

    describe("Relief Partners", function () {
      it("Fund managers should be able to register verified relief partners", async function () {
        const { galanthus, charityLongTerm1 } = await loadFixture(deployGalanthusFixture);

        const tx = await galanthus.addVerifiedReliefPartner(charityLongTerm1)
        await tx.wait()

        const lastVerifiedAddress = await galanthus.getLastVerifiedReliefPartner()
        expect(lastVerifiedAddress).to.equal(charityLongTerm1)
      });

      it("Non fund managers should not be able to register verified relief partners", async function () {
        const { galanthus, charityLongTerm1 } = await loadFixture(deployGalanthusFixture);

        await expect(galanthus.connect(charityLongTerm1).addVerifiedReliefPartner(charityLongTerm1)).to.be
          .revertedWith("Only fund manager can add verified relief partners")
      });

      it("Fund managers should be able to remove verified relief partners", async function () {
        const { galanthus, charityLongTerm1, charityLongTerm2 } = await loadFixture(deployGalanthusFixture);

        await galanthus.addVerifiedReliefPartner(charityLongTerm1)
        await galanthus.addVerifiedReliefPartner(charityLongTerm2)
        
        expect(await galanthus.getLastVerifiedReliefPartner()).to.equal(charityLongTerm2)

        await galanthus.removeVerifiedReliefPartner(charityLongTerm2)
        expect(await galanthus.getLastVerifiedReliefPartner()).to.equal(charityLongTerm1)
      });
    })

    describe("Proposals and Quadratic Voting", function() {
      it("Quadratic voting should determine correct number of votes given a balance of GAL tokens", async function () {
        const { galanthus } = await loadFixture(deployGalanthusFixture);
        expect(await galanthus.quadraticValue(100)).to.equal(6);
        expect(await galanthus.quadraticValue(10)).to.equal(2);
        expect(await galanthus.quadraticValue(1)).to.equal(1);
      })
    })
  })

  // describe("Fund Contract", function () {
  //   describe("Donations", function () {
  //     it("Donor should donate and get governance tokens in exchange", async function () {
  //       const { galanthus, donor1 } = await loadFixture(deployGalanthusFixture);

  //       // await galanthus.connect(donor1).donate(1)
  //       // const contractBalance = await ethers.provider.getBalance(donor1.address);
  //       // console.log(contractBalance)
  //       // expect(contractBalance).to.equal(1)
  //       // console.log('BEFORE = ', await ethers.provider.getBalance(donor1.address))


  //       await galanthus.connect(donor1).donate({ value: 1000 })
  //       const fundContractBalance = await ethers.provider.getBalance(galanthus.target)
  //       expect(fundContractBalance).to.equal(1000)
  //     });
  //   })  
  // })
});
