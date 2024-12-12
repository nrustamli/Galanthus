// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("GalanthusModule", (m) => {
  const initialSupply = m.getParameter("initialSupply", 1000000);
  const token = m.contract("Galanthus", [initialSupply]);

  return { token };
});

