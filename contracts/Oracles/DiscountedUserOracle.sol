// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/Ownable.sol";

// INTERFACES
interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
}

contract DiscountedUserOracle is Ownable {
    // $EASY Contract and Min amount
    address public easyTokenAddress;
    uint256 public easyTokenDiscountAmount = 10000 * 10e18; // Default: 10,000 $EASY
    // Predefined Free Users
    mapping(address => bool) public freeUser;

    function isDiscountedUser(address _user) external view returns (bool) {
        return freeUser[_user] || IERC20(easyTokenAddress).balanceOf(_user) >= easyTokenDiscountAmount;
    }

    // Owner functions
    function setEasyContract(address _address) external onlyOwner {
        easyTokenAddress = _address;
    }

    function setDiscountAmount(uint256 _amount) external onlyOwner {
        easyTokenDiscountAmount = _amount;
    }

    function setFreeUser(address _user, bool _isFree) external onlyOwner {
        freeUser[_user] = _isFree;
    }
}