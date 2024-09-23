// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenFaucet is ReentrancyGuard {
  // Actually supertoken but ERC20 is enough since only need balanceOf() and transfer()
  IERC20 constant fDAIx = IERC20(0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f);

  constructor() {}

  function claim() external nonReentrant {
    require(elligible(msg.sender), "TF: You already own >= 1000 fDAIx");
    fDAIx.transfer(msg.sender, 10000 ether);
  }

  function elligible(address _wallet) public view returns (bool) {
    return fDAIx.balanceOf(_wallet) <= 1000 ether;
  }
}
