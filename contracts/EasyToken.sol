// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/ERC20/ERC20.sol";
import "./libs/Ownable.sol";

contract EasyBackupToken is ERC20, Ownable {
    // MAX_POSSIBLE_SUPPLY = 10000000 * 1e18
    // Locked Developer Funds
    uint256 lastMintTimestamp;
    uint256 lockedDeveloperFunds; 
    uint256 unlockTimestmap;
    // Farm Allocation
    address farmAddress;
    bool farmAddressSet = false;
    uint256 mintableFarmTokens = 4000000 * 1e18; // 4 million
    // Presale Allocation
    address presaleAddress;
    bool presaleSet = false;
    uint256 mintablePresaleTokens = 3500000 * 1e18; // 3.5 million

    constructor() ERC20("EasyBlock", "EASY") {
        _mint(msg.sender, 1000000 * 10**decimals()); // 1,000,000 tokens: Initial Developer Funds

        // Locked Developer Funds
        lastMintTimestamp = block.timestamp;
        unlockTimestmap = block.timestamp + 365 days;
        lockedDeveloperFunds = 1000000 * 10**decimals(); // 1,000,000 tokens: Linearly vested for 1 year
    }
    // Locked Developer Funds
    function mintVestedTokens() external onlyOwner {
        uint256 currentTimestamp = block.timestamp > unlockTimestmap ? unlockTimestmap : block.timestamp;
        uint256 amount = lockedDeveloperFunds * (currentTimestamp - lastMintTimestamp) / 365 days;
        lastMintTimestamp = block.timestamp;
        _mint(msg.sender, amount);
    }
    // Farm Allocation
    function setFarmAddress(address _address) external onlyOwner {
        require(!farmAddressSet, "Farm address already set");
        farmAddress = _address;
        farmAddressSet = true;
    }

    function farmMint(uint256 _amount) external {
        require(msg.sender == farmAddress, "Only farm can mint");
        _mint(msg.sender, _amount);
        mintableFarmTokens -= _amount;
    }
    // Presale Allocation
    function setPresaleAddress(address _address) external onlyOwner {
        require(!presaleSet, "Presale address already set");
        presaleAddress = _address;
        presaleSet = true;
    }

    function presaleMint(uint256 _amount) external {
        require(msg.sender == presaleAddress, "Only presale can mint");
        _mint(msg.sender, _amount);
        _mint(owner(), _amount / 7); // 500,000 tokens max: Initial Liquidity
        mintablePresaleTokens -= _amount;
    }
}