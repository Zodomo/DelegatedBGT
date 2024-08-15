// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// chosen to use an initializer instead of a constructor
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// chosen not to use Solady because EIP-2612 is not needed
import {
    ERC20Upgradeable,
    IERC20,
    IERC20Metadata
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20VotesUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { IDelegateRegistry } from "delegate-registry/src/IDelegateRegistry.sol";

import { Utils } from "../libraries/Utils.sol";
import { IBGT } from "./interfaces/IBGT.sol";
import { IBeraChef } from "./interfaces/IBeraChef.sol";
import { BGTStaker } from "./BGTStaker.sol";

/// @title Bera Governance Token
/// @author Berachain Team
/// @dev Should be owned by the governance module.
/// @dev Only allows minting BGT by the BlockRewardController contract.
/// @dev It's not upgradable even though it inherits from `ERC20VotesUpgradeable` and `OwnableUpgradeable`.
contract BGT is IBGT, ERC20VotesUpgradeable, OwnableUpgradeable {
    using Utils for bytes4;

    string private constant NAME = "Bera Governance Token";
    string private constant SYMBOL = "BGT";

    /// @dev The length of the history buffer.
    uint32 private constant HISTORY_BUFFER_LENGTH = 8191;

    /// @dev Represents 100%. Chosen to be less granular.
    uint256 private constant ONE_HUNDRED_PERCENT = 1e4;

    /// @dev Represents 10%.
    uint256 private constant TEN_PERCENT = 1e3;

    /// @dev Canonical Delegate Registry address, optimal to replace with precompile
    IDelegateRegistry private constant DELEGATE_REGISTRY = IDelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The address of the BlockRewardController contract.
    address internal _blockRewardController;

    /// @notice The BeraChef contract that we are getting the operators for coinbase validators from.
    IBeraChef public beraChef;

    BGTStaker public staker;

    /// @notice The struct of queued boosts
    /// @param blockNumberLast The last block number boost balance was queued
    /// @param balance The queued BGT balance to boost with
    struct QueuedBoost {
        uint32 blockNumberLast;
        uint128 balance;
    }

    /// @notice The struct of user boosts
    /// @param boost The boost balance being used by the user
    /// @param queuedBoost The queued boost balance to be used by the user
    struct UserBoost {
        uint128 boost;
        uint128 queuedBoost;
    }

    /// @notice The struct of validator commissions
    /// @param blockNumberLast The last block number commission rate was updated
    /// @param rate The commission rate for the validator
    struct Commission {
        uint32 blockNumberLast;
        uint224 rate;
    }

    /// @notice Total amount of BGT used for validator boosts
    uint128 public totalBoosts;

    /// @notice The mapping of queued boosts on a validator by an account
    mapping(address account => mapping(address validator => QueuedBoost)) public boostedQueue;

    /// @notice The mapping of balances used to boost validator rewards by an account
    mapping(address account => mapping(address validator => uint128)) public boosted;

    /// @notice The mapping of boost balances used by an account
    mapping(address account => UserBoost) internal userBoosts;

    /// @notice The mapping of boost balances for a validator
    mapping(address validator => uint128) public boostees;

    /// @notice The mapping of validator commission rates charged on new block rewards
    mapping(address validator => Commission) public commissions;

    /// @notice The mapping of approved senders.
    mapping(address sender => bool) public isWhitelistedSender;

    /// @notice Initializes the BGT contract.
    /// @dev Should be called only once by the deployer in the same transaction.
    /// @dev Used instead of a constructor to make the `CREATE2` address independent of constructor arguments.
    function initialize(address owner) external initializer {
        __Ownable_init(owner);
        __ERC20_init(NAME, SYMBOL);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ACCESS CONTROL                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Throws if called by any account other than BlockRewardController.
    modifier onlyBlockRewardController() {
        if (msg.sender != _blockRewardController) NotBlockRewardController.selector.revertWith();
        _;
    }

    /// @dev Throws if the caller is not an approved sender.
    modifier onlyApprovedSender(address sender) {
        if (!isWhitelistedSender[sender]) NotApprovedSender.selector.revertWith();
        _;
    }

    /// @dev Throws if sender available unboosted balance less than amount
    modifier checkUnboostedBalance(address sender, uint256 amount) {
        _checkUnboostedBalance(sender, amount);
        _;
    }

    /// @dev Throws if the `msg.sender` doesn't have a delegation from `source` for this (BGT) contract
    modifier checkDelegation(address source) {
        if (!DELEGATE_REGISTRY.checkDelegateForContract(msg.sender, source, address(this), bytes32(''))) {
            NotDelegate.selector.revertWith();
        }
        _;
    }

    /// @notice check the invariant of the contract after the write operation
    modifier invariantCheck() {
        /// Run the method.
        _;

        /// Ensure that the contract is in a valid state after the write operation.
        _invariantCheck();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IBGT
    function whitelistSender(address sender, bool approved) external onlyOwner {
        isWhitelistedSender[sender] = approved;
        emit SenderWhitelisted(sender, approved);
    }

    /// @inheritdoc IBGT
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) InvalidMinter.selector.revertWith();
        emit MinterChanged(_blockRewardController, _minter);
        _blockRewardController = _minter;
    }

    /// @inheritdoc IBGT
    function mint(address distributor, uint256 amount) external onlyBlockRewardController invariantCheck {
        super._mint(distributor, amount);
    }

    /// @inheritdoc IBGT
    function setBeraChef(address _beraChef) external onlyOwner {
        if (_beraChef == address(0)) ZeroAddress.selector.revertWith();
        emit BeraChefChanged(address(beraChef), _beraChef);
        beraChef = IBeraChef(_beraChef);
    }

    function setStaker(address _staker) external onlyOwner {
        if (_staker == address(0)) ZeroAddress.selector.revertWith();
        // emit StakerChanged(address(staker), _staker);
        staker = BGTStaker(_staker);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    VALIDATOR BOOSTS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _queueBoost(address source, address validator, uint128 amount) private {
        userBoosts[source].queuedBoost += amount;
        unchecked {
            QueuedBoost storage qb = boostedQueue[source][validator];
            // `userBoosts[source].queuedBoost` >= `qb.balance`
            // if the former doesn't overflow, the latter won't
            uint128 balance = qb.balance + amount;
            (qb.balance, qb.blockNumberLast) = (balance, uint32(block.number));
        }
        emit QueueBoost(source, validator, amount);
    }

    /// @inheritdoc IBGT
    function queueBoost(address validator, uint128 amount) external checkUnboostedBalance(msg.sender, amount) {
        _queueBoost(msg.sender, validator, amount);
    }

    /// @inheritdoc IBGT
    function queueBoost(address source, address validator, uint128 amount) external checkUnboostedBalance(source, amount) checkDelegation(source) {
        _queueBoost(source, validator, amount);
    }

    function _cancelBoost(address source, address validator, uint128 amount) private {
        QueuedBoost storage qb = boostedQueue[source][validator];
        qb.balance -= amount;
        unchecked {
            // `userBoosts[source].queuedBoost` >= `qb.balance`
            // if the latter doesn't underflow, the former won't
            userBoosts[source].queuedBoost -= amount;
        }
        emit CancelBoost(source, validator, amount);
    }

    /// @inheritdoc IBGT
    function cancelBoost(address validator, uint128 amount) external {
        _cancelBoost(msg.sender, validator, amount);
    }

    /// @inheritdoc IBGT
    function cancelBoost(address source, address validator, uint128 amount) external checkDelegation(source) {
        _cancelBoost(source, validator, amount);
    }

    function _activateBoost(address source, address validator) private {
        QueuedBoost storage qb = boostedQueue[source][validator];
        (uint32 blockNumberLast, uint128 amount) = (qb.blockNumberLast, qb.balance);
        _checkEnoughTimePassed(blockNumberLast);

        totalBoosts += amount;
        unchecked {
            // `totalBoosts` >= `boostees[validator]` >= `boosted[source][validator]`
            boostees[validator] += amount;
            boosted[source][validator] += amount;
            UserBoost storage userBoost = userBoosts[source];
            (uint128 boost, uint128 _queuedBoost) = (userBoost.boost, userBoost.queuedBoost);
            // `totalBoosts` >= `userBoosts[source].boost`
            // `userBoosts[source].queuedBoost` >= `boostedQueue[source][validator].balance`
            (userBoost.boost, userBoost.queuedBoost) = (boost + amount, _queuedBoost - amount);
        }
        delete boostedQueue[source][validator];

        staker.stake(source, amount);

        emit ActivateBoost(source, validator, amount);
    }

    /// @inheritdoc IBGT
    function activateBoost(address validator) external {
        _activateBoost(msg.sender, validator);
    }

    /// @inheritdoc IBGT
    function activateBoost(address source, address validator) external checkDelegation(source) {
        _activateBoost(source, validator);
    }

    // DROP BOOST

    function _dropBoost(address source, address validator, uint128 amount) private {
        boosted[source][validator] -= amount;
        unchecked {
            // `totalBoosts` >= `userBoosts[source].boost` >= `boosted[source][validator]`
            totalBoosts -= amount;
            userBoosts[source].boost -= amount;
            // `totalBoosts` >= `boostees[validator]` >= `boosted[source][validator]`
            boostees[validator] -= amount;
        }

        staker.withdraw(source, amount);

        emit DropBoost(source, validator, amount);
    }

    /// @inheritdoc IBGT
    function dropBoost(address validator, uint128 amount) external {
        _dropBoost(msg.sender, validator, amount);
    }

    function dropBoost(address source, address validator, uint128 amount) external checkDelegation(source) {
        _dropBoost(source, validator, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  VALIDATOR COMMISSIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IBGT
    function setCommission(address validator, uint256 rate) external {
        if (msg.sender != validator) {
            if (msg.sender != beraChef.getOperator(validator)) NotValidatorOrOperator.selector.revertWith();
        }
        if (rate > TEN_PERCENT) InvalidCommission.selector.revertWith();

        Commission storage c = commissions[validator];
        (uint32 blockNumberLast, uint224 currentRate) = (c.blockNumberLast, c.rate);
        if (blockNumberLast > 0) _checkEnoughTimePassed(blockNumberLast);
        (c.blockNumberLast, c.rate) = (uint32(block.number), uint224(rate));

        emit UpdateCommission(validator, currentRate, rate);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ERC20 FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IERC20
    /// @dev Only allows approve if the caller is an approved sender.
    function approve(
        address spender,
        uint256 amount
    )
        public
        override(IERC20, ERC20Upgradeable)
        onlyApprovedSender(msg.sender)
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    /// @inheritdoc IERC20
    /// @dev Only allows transfer if the caller is an approved sender and has enough unboosted balance.
    function transfer(
        address to,
        uint256 amount
    )
        public
        override(IERC20, ERC20Upgradeable)
        onlyApprovedSender(msg.sender)
        checkUnboostedBalance(msg.sender, amount)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /// @inheritdoc IERC20
    /// @dev Only allows transferFrom if the from address is an approved sender and has enough unboosted balance.
    /// @dev It spends the allowance of the caller.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    )
        public
        override(IERC20, ERC20Upgradeable)
        onlyApprovedSender(from)
        checkUnboostedBalance(from, amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          WRITES                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IBGT
    function redeem(
        address receiver,
        uint256 amount
    )
        external
        invariantCheck
        checkUnboostedBalance(msg.sender, amount)
    {
        /// Burn the BGT token from the msg.sender account and reduce the total supply.
        super._burn(msg.sender, amount);
        /// Transfer the Native token to the receiver.
        SafeTransferLib.safeTransferETH(receiver, amount);
        emit Redeem(msg.sender, receiver, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          GETTERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IBGT
    function minter() external view returns (address) {
        return _blockRewardController;
    }

    /// @inheritdoc IBGT
    function boostedRewardRate(address validator, uint256 rewardRate) external view returns (uint256) {
        if (totalBoosts == 0) return 0;
        return FixedPointMathLib.fullMulDiv(rewardRate, boostees[validator], totalBoosts);
    }

    /// @inheritdoc IBGT
    function boosts(address account) external view returns (uint128) {
        return userBoosts[account].boost;
    }

    /// @inheritdoc IBGT
    function queuedBoost(address account) external view returns (uint128) {
        return userBoosts[account].queuedBoost;
    }

    /// @inheritdoc IBGT
    function commissionRewardRate(address validator, uint256 rewardRate) external view returns (uint256) {
        return FixedPointMathLib.fullMulDiv(rewardRate, commissions[validator].rate, ONE_HUNDRED_PERCENT);
    }

    /// @inheritdoc IERC20Metadata
    function name() public pure override(IERC20Metadata, ERC20Upgradeable) returns (string memory) {
        return NAME;
    }

    /// @inheritdoc IERC20Metadata
    function symbol() public pure override(IERC20Metadata, ERC20Upgradeable) returns (string memory) {
        return SYMBOL;
    }

    //. @inheritdoc IBGT
    function unboostedBalanceOf(address account) public view returns (uint256) {
        UserBoost storage userBoost = userBoosts[account];
        (uint128 boost, uint128 _queuedBoost) = (userBoost.boost, userBoost.queuedBoost);
        return balanceOf(account) - boost - _queuedBoost;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          INTERNAL                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _checkUnboostedBalance(address sender, uint256 amount) private view {
        if (unboostedBalanceOf(sender) < amount) NotEnoughBalance.selector.revertWith();
    }

    function _checkEnoughTimePassed(uint32 blockNumberLast) private view {
        unchecked {
            uint32 delta = uint32(block.number) - blockNumberLast;
            if (delta <= HISTORY_BUFFER_LENGTH) NotEnoughTime.selector.revertWith();
        }
    }

    function _invariantCheck() internal view {
        if (address(this).balance < totalSupply()) InvariantCheckFailed.selector.revertWith();
    }
}
