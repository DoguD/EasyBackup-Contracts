// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/ERC20/ERC20.sol";
import "./libs/Ownable.sol";

contract EasyToken is ERC20, Ownable {
    // Token Allocations
    uint256 public constant MAX_POSSIBLE_SUPPLY = 10000000 * 1e18; // 10 million
    uint256 public constant INITIAL_DEVELOPER_ALLOCATION = MAX_POSSIBLE_SUPPLY / 10; // 1 million
    uint256 public constant LOCKED_DEVELOPER_ALLOCATION = MAX_POSSIBLE_SUPPLY / 10; // 1 million (vested over 1 year)
    uint256 public constant FARM_ALLOCATION = MAX_POSSIBLE_SUPPLY * 4 / 10; // 4 million (distributed over 1 year)
    uint256 public constant PRESALE_ALLOCATION = MAX_POSSIBLE_SUPPLY * 35 / 100; // 3.5 million
    uint256 public constant LIQUIDITY_ALLOCATION = MAX_POSSIBLE_SUPPLY * 5 / 100; // 0.5 million

    // Locked Developer Allocation
    uint256 public lastMintTimestamp;
    uint256 public unlockTimestmap;
    // Farm Allocation
    address public farmAddress;
    uint256 public mintedFarmTokens = 0;
    // Presale Allocation
    address public presaleAddress;
    uint256 public mintedPresaleTokens = 0;

    constructor() ERC20("EasyBlock", "EASY") {
        _mint(msg.sender, INITIAL_DEVELOPER_ALLOCATION);

        // Locked Developer Funds
        lastMintTimestamp = block.timestamp;
        unlockTimestmap = block.timestamp + 365 days;
    }

    // Locked Developer Funds
    function mintVestedTokens() external onlyOwner {
        uint256 currentTimestamp = block.timestamp > unlockTimestmap ? unlockTimestmap : block.timestamp;
        uint256 passedTimeSinceLastMint = currentTimestamp - lastMintTimestamp;
        uint256 amount = LOCKED_DEVELOPER_ALLOCATION * passedTimeSinceLastMint / 365 days;
        lastMintTimestamp = currentTimestamp;
        _mint(msg.sender, amount);
    }

    // Farm Allocation
    function setFarmAddress(address _address) external onlyOwner {
        farmAddress = _address;
    }

    function farmMint(address _to, uint256 _amount) external {
        require(msg.sender == farmAddress, "Only farm can mint");
        require(
            mintedFarmTokens + _amount <= FARM_ALLOCATION,
            "Farm allocation exceeded"
        );
        mintedFarmTokens += _amount;
        _mint(_to, _amount);
    }

    // Presale Allocation
    function setPresaleAddress(address _address) external onlyOwner {
        presaleAddress = _address;
    }

    function presaleMint(uint256 _amount, address _buyer) external {
        require(msg.sender == presaleAddress, "Only presale can mint");
        require(
            mintedPresaleTokens + _amount <= PRESALE_ALLOCATION,
            "Presale allocation exceeded"
        );
        mintedPresaleTokens += _amount;
        _mint(_buyer, _amount);
        _mint(owner(), _amount / 7); // Liquidity Allocation
    }
}
