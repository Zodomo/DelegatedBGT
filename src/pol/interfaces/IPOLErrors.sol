// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

/// @notice Interface of POL errors
interface IPOLErrors {
    error NotApprovedSender();
    error NotRootFollower();
    error NotProver();
    error NotDelegate();
    error NotBGT();
    error NotBlockRewardController();
    error NotDistributor();
    error NotFeeCollector();
    error NotFriendOfTheChef();
    error NotGovernance();
    error NotOperator();
    error NotValidatorOrOperator();
    error NotEnoughBalance();
    error NotEnoughTime();
    error InvalidMinter();
    error InvalidStartBlock();
    error InvalidCuttingBoardWeights();
    error InvalidCommission();
    error QueuedCuttingBoardNotReady();
    error QueuedCuttingBoardNotFound();
    error TooManyWeights();
    error AlreadyInitialized();
    error VaultAlreadyExists();
    error ZeroAddress();

    /*                           STAKING                           */

    error CannotRecoverRewardToken();
    error CannotRecoverStakingToken();
    error DelegateStakedOverflow();
    error InsolventReward();
    error InsufficientStake();
    error RewardCycleNotEnded();
    error StakeAmountIsZero();
    error TotalSupplyOverflow();
    error WithdrawAmountIsZero();

    error TokenNotWhitelisted();
    error NoWhitelistedTokens();
    error InsufficientDelegateStake();
    error InsufficientSelfStake();
    error TokenAlreadyWhitelistedOrLimitReached();
    error AmountLessThanMinIncentiveRate();
    error InvalidMaxIncentiveTokensCount();

    error PayoutAmountIsZero();
    error PayoutTokenIsZero();
    error MaxNumWeightsPerCuttingBoardIsZero();

    /// @dev Unauthorized caller
    error Unauthorized(address);
    /// @dev The queried block is not in the buffer range
    error BlockNotInBuffer();
    /// @dev distributeFor was called with a block number that is not the next actionable block
    error NotActionableBlock();
    /// @dev The block number does not exist yet
    error BlockDoesNotExist();
    error InvariantCheckFailed();
}
