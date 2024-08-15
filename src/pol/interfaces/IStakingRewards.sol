// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import { IPOLErrors } from "./IPOLErrors.sol";

interface IStakingRewards is IPOLErrors {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a reward has been added to the vault.
    /// @param reward The amount of reward added.
    event RewardAdded(uint256 reward);

    /// @notice Emitted when the staking balance of an account has increased.
    /// @param account The account that has staked.
    /// @param amount The amount of staked tokens.
    event Staked(address indexed account, uint256 amount);

    /// @notice Emitted when the staking balance of an account has decreased.
    /// @param account The account that has withdrawn.
    /// @param amount The amount of withdrawn tokens.
    event Withdrawn(address indexed account, uint256 amount);

    /// @notice Emitted when a reward has been claimed.
    /// @param account The account whose reward has been claimed.
    /// @param to The address that the reward was sent to. (user or operator).
    /// @param reward The amount of reward claimed.
    event RewardPaid(address indexed account, address to, uint256 reward);

    /// @notice Emitted when the reward duration has been updated.
    /// @param newDuration The new duration of the reward.
    event RewardsDurationUpdated(uint256 newDuration);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          GETTERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Get the balance of the staked tokens for an account.
    /// @param account The account to get the balance for.
    /// @return The balance of the staked tokens.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Retrieves the amount of reward earned by a specific account.
    /// @param account The account to calculate the reward for.
    /// @return The amount of reward earned by the account.
    function earned(address account) external view returns (uint256);

    /// @notice Retrieves the total reward vested over the specified duration.
    /// @return The total reward vested over the duration.
    function getRewardForDuration() external view returns (uint256);

    /// @notice Returns the timestamp of the last reward distribution. This is either the current timestamp (if rewards
    /// are still being actively distributed) or the timestamp when the reward duration ended (if all rewards have
    /// already been distributed).
    /// @return The timestamp of the last reward distribution.
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Retrieves the current value of the global reward per token accumulator. This value is the sum of the
    /// last checkpoint value and the accumulated value since the last checkpoint. It should increase monotonically
    /// over time as more rewards are distributed.
    /// @return The current value of the global reward per token accumulator scaled by 1e18.
    function rewardPerToken() external view returns (uint256);

    /// @notice Get the total supply of the staked tokens in the vault.
    /// @return The total supply of the staked tokens in the vault.
    function totalSupply() external view returns (uint256);
}
