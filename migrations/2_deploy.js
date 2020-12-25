const wanFarm = artifacts.require("wanFarm");

module.exports = function (deployer) {
  // deployer.deploy(Migrations);
  deployer.deploy(wanFarm, '0xdabd997ae5e4799be47d6e69d9431615cba28f48', '0xdabd997ae5e4799be47d6e69d9431615cba28f48');
};

