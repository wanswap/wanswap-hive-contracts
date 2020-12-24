// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ERC20B is ERC20("ERC20B", "ERC20B"), Ownable {
    constructor() public {
        _mint(address(0x761E4aD0ce9978DdaD68C819c229Af48Db2214DA), 100000000 ether);
    }
    function mint(address _to) public {
        _mint(_to, 100000000 ether);
    }
}
