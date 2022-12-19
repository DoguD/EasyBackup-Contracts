// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/ERC20/ERC20.sol";
import "./libs/Ownable.sol";

contract EasyBackupToken is ERC20, Ownable {
    // Token Allocations
    uint256 public constant MAX_POSSIBLE_SUPPLY = 10000000 * 1e18; // 10 million
    uint256 public constant INITIAL_DEVELOPER_ALLOCATION =
        MAX_POSSIBLE_SUPPLY / 10; // 1 million
    uint256 public constant LOCKED_DEVELOPER_ALLOCATION =
        MAX_POSSIBLE_SUPPLY / 10; // 1 million
    uint256 public constant FARM_ALLOCATION = (MAX_POSSIBLE_SUPPLY * 4) / 10; // 4 million
    uint256 public constant PRESALE_ALLOCATION =
        (MAX_POSSIBLE_SUPPLY * 35) / 100; // 3.5 million
    uint256 public constant LIQUIDITY_ALLOCATION =
        (MAX_POSSIBLE_SUPPLY * 5) / 100; // 0.5 million
        
    // Locked Developer Funds
    uint256 lastMintTimestamp;
    uint256 unlockTimestmap;
    // Farm Allocation
    address farmAddress;
    bool farmAddressSet = false;
    uint256 mintedFarmTokens = 0;
    // Presale Allocation
    address presaleAddress;
    bool presaleSet = false;
    uint256 mintedPresaleTokens = 0;

    constructor() ERC20("EasyBlock", "EASY") {
        _mint(msg.sender, INITIAL_DEVELOPER_ALLOCATION);

        // Locked Developer Funds
        lastMintTimestamp = block.timestamp;
        unlockTimestmap = block.timestamp + 365 days;
    }

    // Locked Developer Funds
    function mintVestedTokens() external onlyOwner {
        uint256 currentTimestamp = block.timestamp > unlockTimestmap
            ? unlockTimestmap
            : block.timestamp;
        uint256 amount = (LOCKED_DEVELOPER_ALLOCATION *
            (currentTimestamp - lastMintTimestamp)) / 365 days;
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
        require(
            mintedFarmTokens + _amount <= FARM_ALLOCATION,
            "Farm allocation exceeded"
        );
        mintedFarmTokens -= _amount;
        _mint(msg.sender, _amount);
    }

    // Presale Allocation
    function setPresaleAddress(address _address) external onlyOwner {
        require(!presaleSet, "Presale address already set");
        presaleAddress = _address;
        presaleSet = true;
    }

    function presaleMint(uint256 _amount, address _buyer) external {
        require(msg.sender == presaleAddress, "Only presale can mint");
        require(
            mintedPresaleTokens + _amount <= PRESALE_ALLOCATION,
            "Presale allocation exceeded"
        );
        _mint(_buyer, _amount);
        _mint(owner(), _amount / 7);
        mintedPresaleTokens += _amount;
    }
}
