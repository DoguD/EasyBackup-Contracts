// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
import "./libs/Context.sol";
import "./libs/Address.sol";
import "./libs/ERC20/IERC20.sol";
import "./libs/ERC20/ERC20.sol";

// xEasy is the staked version of Easy Token which earns 90% of platform revenue
contract xEasyBlock is ERC20("xEasyBlock", "xEASY") {
    IERC20 public easy;

    // Define the Easy token contract
    constructor(address _easyAddresss) public {
        easy = IERC20(_easyAddresss);
    }

    // Locks Easy and mint xEasy
    function enter(uint256 _amount) public {
        // Gets the amount of Easy locked in the contract
        uint256 totalEasy = easy.balanceOf(address(this));
        // Gets the amount of xEasy in existence
        uint256 totalShares = totalSupply();
        // If no xEasy exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalEasy == 0) {
            mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xEasy the Easy is worth. The ratio will change overtime, as xEasy is burned/minted and Easy deposited + gained from fees / withdrawn.
        else {
            uint256 mintAmount = _amount * totalShares / totalEasy;
            mint(msg.sender, mintAmount);
        }
        // Lock the Boo in the contract
        require(easy.transferFrom(msg.sender, address(this), _amount), "Easy transfer failed");
    }

    // Unlocks the staked + gained Easy and burns xEasy
    function leave(uint256 _share) public {
        // Gets the amount of xEasy in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Easy the xEasy is worth
        uint256 easyAmount = _share * easy.balanceOf(address(this)) / totalShares;
        burn(msg.sender, _share);
        easy.transfer(msg.sender, easyAmount);
    }

    // returns the total amount of Easy an address has in the contract including fees earned
    function EASYBalance(address _account) external view returns (uint256 easyAmount_) {
        uint256 xEasyAmount = balanceOf(_account);
        uint256 totalxEasy = totalSupply();
        easyAmount_ = xEasyAmount * easy.balanceOf(address(this)) / totalxEasy;
    }

    // returns how much Easy someone gets for redeeming xEasy
    function xEasyForEasy(uint256 _xEasyAmount) external view returns (uint256 easyAmount_) {
        uint256 totalxEasy = totalSupply();
        easyAmount_ = _xEasyAmount * easy.balanceOf(address(this)) / totalxEasy;
    }

    // returns how much xEasy someone gets for depositing Easy
    function EasyForxEasy(uint256 _easyAmount) external view returns (uint256 xEasyAmount_) {
        uint256 totalEasy = easy.balanceOf(address(this));
        uint256 totalxEasy = totalSupply();
        if (totalxEasy == 0 || totalEasy == 0) {
            xEasyAmount_ = _easyAmount;
        }
        else {
            xEasyAmount_ = _easyAmount * totalxEasy / totalEasy;
        }
    }

    function addReward(uint256 _easyAmount) external {
        require(_easyAmount > 0, "Cannot add 0");
        easy.transferFrom(msg.sender, address(this), _easyAmount);
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    // A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    // A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    
    function burn(address _from, uint256 _amount) private {
        _burn(_from, _amount);
        _moveDelegates(_delegates[_from], address(0), _amount);
    }

    function mint(address recipient, uint256 _amount) private {
        _mint(recipient, _amount);

        _initDelegates(recipient);

        _moveDelegates(address(0), _delegates[recipient], _amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) 
    public virtual override returns (bool)
    {
        bool result = super.transferFrom(sender, recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[sender], _delegates[recipient], amount);

        return result;
    }

    function transfer(address recipient, uint256 amount) 
    public virtual override returns (bool)
    {
        bool result = super.transfer(recipient, amount); // Call parent hook

        _initDelegates(recipient);

        _moveDelegates(_delegates[_msgSender()], _delegates[recipient], amount);

        return result;
    }

    // initialize delegates mapping of recipient if not already
    function _initDelegates(address recipient) internal {
        if(_delegates[recipient] == address(0)) {
            _delegates[recipient] = recipient;
        }
    }

    /**
     * @param delegator The address to get delegates for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "BOO::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "BOO::delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "BOO::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "BOO::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying BOOs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld - amount;
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld + amount;
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "BOO::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal view returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

}