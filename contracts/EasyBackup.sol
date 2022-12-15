// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/Ownable.sol";

interface EthPriceOracle {
    function getEthPrice() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining);
}

contract EasyBackup is Ownable {
    // Backup object
    struct Backup {
        address from;
        address to;
        address token;
        uint256 amount;
        uint256 expiry;
        bool isActive;
    }

    // Constants
    uint256 public constant MAX_CLAIM_FEE = 100; // Basis points, max 1%
    // Manager Variables
    uint256 public claimFee = 100; // Basis points, default 1%
    uint256 public initFeeUsd = 100; // In 0.01 USD, default $1
    address public ethPriceOracleAddress;
    EthPriceOracle ethPriceOracle;
    address public feeCollector;
    // User Variables
    mapping(address => uint256) public lastInteraction;
    mapping(uint256 => Backup) public backups;
    uint256 public backupCount;
    mapping(address => uint256[]) public createdBackups;
    mapping(address => uint256[]) public claimableBackups;

    // USER FUNCTIONS
    function heartBeat() public {
        lastInteraction[msg.sender] = block.timestamp;
    }

    // Backup creation and editing
    function createBackup(
        address _to,
        address _token,
        uint256 _amount,
        uint256 _expiry
    ) external payable {
        require(msg.value >= getInitFee(), "Insufficient fee");
        lastInteraction[msg.sender] = block.timestamp;

        backups[backupCount] = Backup(
            msg.sender,
            _to,
            _token,
            _amount,
            _expiry,
            true
        );
        createdBackups[msg.sender].push(backupCount);
        claimableBackups[_to].push(backupCount);
        backupCount++;
    }

    function editBackup(
        uint256 _id,
        uint256 _amount,
        uint256 _expiry
    ) external {
        require(backups[_id].from == msg.sender, "Not your backup");
        lastInteraction[msg.sender] = block.timestamp;

        backups[_id].amount = _amount;
        backups[_id].expiry = _expiry;
    }

    function deletBackup(uint256 _id) external {
        require(backups[_id].from == msg.sender, "Not your backup");
        lastInteraction[msg.sender] = block.timestamp;

        backups[_id].isActive = false;
    }

    // Backup claiming
    function claimBackup(uint256 _id) external {
        require(backups[_id].to == msg.sender, "Not your backup");
        require(
            backups[_id].expiry + lastInteraction[backups[_id].from] >
                block.timestamp,
            "Too early"
        );
        require(backups[_id].isActive, "Backup inactive");

        lastInteraction[msg.sender] = block.timestamp;

        // Calculate amount, minimum of balance, allowance, backup amount
        uint256 amount = min(
            IERC20(backups[_id].token).balanceOf(backups[_id].from),
            IERC20(backups[_id].token).allowance(
                backups[_id].from,
                address(this)
            ),
            backups[_id].amount
        );
        uint256 fee = amount * claimFee / 10000;

        backups[_id].isActive = false;

        require(IERC20(backups[_id].token).transferFrom(backups[_id].from, feeCollector , fee), "Transaction failed");
        require(IERC20(backups[_id].token).transferFrom(backups[_id].from, backups[_id].to , amount - fee), "Transaction failed");
    }

    // HELPER FUNCTIONS
    function getInitFee() public view returns (uint256) {
        return (initFeeUsd * 1e16) / ethPriceOracle.getEthPrice();
    }

    function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        uint256 minNumber;

        if (a < b) {
            minNumber = a;
        } else {
            minNumber = b;
        }

        if (c < minNumber) {
            minNumber = c;
        }

        return minNumber;
    }

    // MANAGER FUNCTIONS
    function setClaimFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_CLAIM_FEE, "Fee too high");
        claimFee = _newFee;
    }

    function setEthPriceOracle(address _newOracle) external onlyOwner {
        ethPriceOracleAddress = _newOracle;
        ethPriceOracle = EthPriceOracle(_newOracle);
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(feeCollector).send(address(this).balance));
    }
}
