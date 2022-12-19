// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/Ownable.sol";

interface IERC20 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);
}

interface EasyToken {
    function presaleMint(uint256 _amount, address _to) external;
}

interface EasyClub {
    function balanceOf(address _address) external view returns (uint256);
}

contract Presale is Ownable {
    uint256 preSaleStartTime;
    uint256 preSaleDuration;
    uint256 saleDuration = 1209600; // 2 weeks

    address public constant currencyAddress =
        0x04068DA6C83AFCFA0e13ba15A6696662335D5B75; // USDC on Fantom
    address public tokenAddress;
    uint256 public constant tokenPrice = 10000; // 0.01 USDC (USDC has 6 decimals)

    EasyClub easyClubContract =
        EasyClub(0x5d6f546f2357E84720371A0510f64DBC3FbACe33);

    constructor(
        uint256 _startTime,
        uint256 _preSaleDuration,
        address _tokenAddress
    ) {
        preSaleStartTime = _startTime;
        preSaleDuration = _preSaleDuration;
        tokenAddress = _tokenAddress;
    }

    function buyTokens(uint256 _amount) external {
        uint8 status = getSaleStatus();
        require(_amount > 1e18, "Amount should be greater than 1");
        require(status == 1 || status == 2, "Sale not active");

        if (status == 1) {
            require(
                easyClubContract.balanceOf(msg.sender) >= 1,
                "Presale is only for EasyClub members"
            );
        }

        IERC20 currency = IERC20(currencyAddress);

        require(currency.transferFrom(msg.sender, owner(), _amount * tokenPrice / 1e18), "Transfer failed");
        EasyToken(tokenAddress).presaleMint(_amount, msg.sender);
    }

    function getSaleStatus() internal view returns (uint8) {
        if (block.timestamp < preSaleStartTime) {
            return 0; // Not started
        } else if (block.timestamp < preSaleStartTime + preSaleDuration) {
            return 1; // Pre-sale
        } else if (
            block.timestamp < preSaleStartTime + preSaleDuration + saleDuration
        ) {
            return 2; // Sale
        } else {
            return 3; // Ended
        }
    }
}
