// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract wanWan is ERC20("wanWan", "wanWan"), Ownable {
    constructor() public {
        _mint(address(0x6a958CD1CeF5de3c285E8aFE5976Ccb927fE787c), 200000000 ether);
    }

    function mint(address _to) public {
        _mint(_to, 100000000 ether);
    }
}
