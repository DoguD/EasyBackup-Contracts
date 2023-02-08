// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./libs/Ownable.sol";

interface EthPriceOracle {
    function getEthPrice() external view returns (uint256, uint256);
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
        bool isAutomatic;
        bool isClaimed;
    }

    // Constants
    uint256 public constant MAX_CLAIM_FEE = 100; // Basis points, max 1%
    // Manager Variables
    uint256 public claimFee = 100; // Basis points, default 1%
    uint256 public initFeeUsd = 1000; // In 0.01 USD, default $10
    address public ethPriceOracleAddress;
    EthPriceOracle ethPriceOracle;
    address public initFeeCollector;
    address public claimFeeCollector;
    bool public isReferralActive;
    uint public referralFee = 5000; // Basis points, default 50%
    // User Variables
    mapping(address => uint256) public lastInteraction;
    mapping(uint256 => Backup) public backups;
    uint256 public backupCount;
    mapping(address => uint256[]) public createdBackups;
    mapping(address => uint256) public createdBackupsCount;
    mapping(address => uint256[]) public claimableBackups;
    mapping(address => uint256) public claimableBackupsCount;
    // Discount for $EASY balance
    address public easyTokenAddress;
    uint256 public easyTokenDiscountAmount = 10000 * 10e18; // Default: 10,000 $EASY
    // Stats
    uint256 public totalUsers;
    uint256 public totalClaims;
    mapping(address => uint256) public claims;

    // EVENTS
    event BackupCreated(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 expiry,
        uint256 id
    );
    event BackupEdited(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 expiry,
        uint256 id
    );
    event BackupDeleted(
        uint256 indexed id
    );
    event BackupClaimed(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 id,
        bool isAutomatic
    );

    // USER FUNCTIONS
    function heartBeat() public {
        lastInteraction[msg.sender] = block.timestamp;
    }

    // Backup creation and editing
    function createBackup(
        address _to,
        address _token,
        uint256 _amount,
        uint256 _expiry,
        bool _isAutomatic,
        address _referral
    ) external payable {
        uint256 fee = getInitFee();
        require(isDiscounted(msg.sender) || msg.value >= fee, "Insufficient fee");
        lastInteraction[msg.sender] = block.timestamp;

        backups[backupCount] = Backup(
            msg.sender,
            _to,
            _token,
            _amount,
            _expiry,
            true,
            _isAutomatic,
            false
        );
        createdBackups[msg.sender].push(backupCount);
        createdBackupsCount[msg.sender]++;
        claimableBackups[_to].push(backupCount);
        claimableBackupsCount[_to]++;

        if(createdBackupsCount[msg.sender] == 1) {
            totalUsers++;
        }

        emit BackupCreated(
            msg.sender,
            _to,
            _token,
            _amount,
            _expiry,
            backupCount
        );

        backupCount++;

        // Referral
        if(isReferralActive && createdBackupsCount[_referral] > 0) {
            require(payable(_referral).send(fee * referralFee / 10000), "Transaction failed");
        }
    }

    function editBackup(
        uint256 _id,
        uint256 _amount,
        uint256 _expiry,
        bool _isAutomatic
    ) external {
        require(backups[_id].from == msg.sender, "Not your backup");
        lastInteraction[msg.sender] = block.timestamp;

        backups[_id].amount = _amount;
        backups[_id].expiry = _expiry;
        backups[_id].isAutomatic = _isAutomatic;

        emit BackupEdited(
            backups[_id].from,
            msg.sender,
            backups[_id].token,
            _amount,
            _expiry,
            _id
        );
    }

    function deleteBackup(uint256 _id) external {
        require(backups[_id].from == msg.sender, "Not your backup");
        lastInteraction[msg.sender] = block.timestamp;

        backups[_id].isActive = false;
        emit BackupDeleted(_id);
    }

    // Backup claiming
    function claimBackup(uint256 _id) external {
        require(backups[_id].to == msg.sender, "Not your backup");
        require(
            backups[_id].expiry + lastInteraction[backups[_id].from] <
                block.timestamp,
            "Too early"
        );
        require(backups[_id].isActive, "Backup inactive");

        lastInteraction[msg.sender] = block.timestamp;

        // Calculate amount, minimum of balance, allowance, backup amount
        uint256 amount = getClaimableAmount(_id);
        uint256 fee = (amount * claimFee) / 10000;

        backups[_id].isActive = false;
        backups[_id].isClaimed = true;

        require(
            IERC20(backups[_id].token).transferFrom(
                backups[_id].from,
                claimFeeCollector,
                fee
            ),
            "Transaction failed"
        );
        require(
            IERC20(backups[_id].token).transferFrom(
                backups[_id].from,
                backups[_id].to,
                amount - fee
            ),
            "Transaction failed"
        );

        claims[backups[_id].token] += amount;
        totalClaims += 1;

        emit BackupClaimed(
            backups[_id].from,
            backups[_id].to,
            backups[_id].token,
            amount,
            _id,
            false
        );
    }

    // Automatic claiming
    function claimBackupAuto(uint256 _id) external {
        require(backups[_id].isAutomatic, "Not automatic");
        require(
            backups[_id].expiry + lastInteraction[backups[_id].from] <
                block.timestamp,
            "Too early"
        );
        require(backups[_id].isActive, "Backup inactive");

        lastInteraction[msg.sender] = block.timestamp;

        // Calculate amount, minimum of balance, allowance, backup amount
        uint256 amount = getClaimableAmount(_id);
        uint256 fee = (amount * claimFee) / 10000;

        backups[_id].isActive = false;
        backups[_id].isClaimed = true;

        require(
            IERC20(backups[_id].token).transferFrom(
                backups[_id].from,
                claimFeeCollector,
                fee
            ),
            "Transaction failed"
        );
        require(
            IERC20(backups[_id].token).transferFrom(
                backups[_id].from,
                backups[_id].to,
                amount - fee
            ),
            "Transaction failed"
        );

        claims[backups[_id].token] += amount;
        totalClaims += 1;

        emit BackupClaimed(
            backups[_id].from,
            backups[_id].to,
            backups[_id].token,
            amount,
            _id,
            true
        );
    }

    // HELPER FUNCTIONS
    function getInitFee() public view returns (uint256) {
        (uint256 _price, uint256 _decimals) = ethPriceOracle.getEthPrice();
        uint256 _fee = (initFeeUsd * 1e16 * (10 ** _decimals)) / _price; 
        return _fee / 1e16 * 1e16; // Rounding to two decimals
    }

    function getClaimableAmount(uint256 _id) public view returns (uint256) {
        return min(
            IERC20(backups[_id].token).balanceOf(backups[_id].from),
            IERC20(backups[_id].token).allowance(
                backups[_id].from,
                address(this)
            ),
            backups[_id].amount
        );
    }

    function isDiscounted(address _user) public view returns (bool) {
        return IERC20(easyTokenAddress).balanceOf(_user) >= easyTokenDiscountAmount;
    }

    function min(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256) {
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

    function setInitFeeCollector(address _feeCollector) external onlyOwner {
        initFeeCollector = _feeCollector;
    }

    function setClaimFeeCollector(address _feeCollector) external onlyOwner {
        claimFeeCollector = _feeCollector;
    }

    function setInitFee(uint256 _fee) external onlyOwner {
        initFeeUsd = _fee;
    }

    function setEasyContract(address _address) external onlyOwner {
        easyTokenAddress = _address;
    }

    function setDiscountAmount(uint256 _amount) external onlyOwner {
        easyTokenDiscountAmount = _amount;
    }

    function setIsReferralActive(bool _isActive) external onlyOwner {
        isReferralActive = _isActive;
    }

    function setReferralFee(uint256 _fee) external onlyOwner {
        referralFee = _fee;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(initFeeCollector).send(address(this).balance));
    }
}
