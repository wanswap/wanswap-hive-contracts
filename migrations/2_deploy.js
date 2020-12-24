const wanFarm = artifacts.require("wanFarm");

module.exports = function (deployer) {
  // deployer.deploy(Migrations);
  deployer.deploy(wanFarm, '0x916283cc60fdaf05069796466af164876e35d21f', '0x916283cc60fdaf05069796466af164876e35d21f');
};

