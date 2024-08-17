// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IPOLErrors } from "./IPOLErrors.sol";

interface IBGT is IPOLErrors, IERC20, IERC20Metadata {
    /**
     * @notice Emitted when the minter address is changed.
     * @param previous The address of the previous minter.
     * @param current The address of the current minter.
     */
    event MinterChanged(address indexed previous, address indexed current);

    /**
     * @notice Emitted when the BeraChef address is changed.
     * @param previous The address of the previous BeraChef.
     * @param current The address of the current BeraChef.
     */
    event BeraChefChanged(address indexed previous, address indexed current);

    /**
     * @notice Emitted when an address is approved to send BGT.
     * @param sender The address of the sender.
     * @param approved Whether the sender is approved or not.
     */
    event SenderWhitelisted(address indexed sender, bool approved);

    /**
     * @notice Emitted when sender queues a new boost for a validator with an amount of BGT
     * @param sender The address of the sender.
     * @param validator The address of the validator to be boosted.
     * @param amount The amount of BGT to boost with.
     */
    event QueueBoost(address indexed sender, address indexed validator, uint128 amount);

    /**
     * @notice Emitted when sender cancels a queued boost for a validator with an amount of BGT
     * @param sender The address of the sender.
     * @param validator The address of the validator to be boosted.
     * @param amount The amount of BGT to cancel from queued boosts.
     */
    event CancelBoost(address indexed sender, address indexed validator, uint128 amount);

    /**
     * @notice Emitted when sender activates a new boost for a validator
     * @param sender The address of the sender.
     * @param validator The address of the validator to boost.
     * @param amount The amount of BGT to boost with.
     */
    event ActivateBoost(address indexed sender, address indexed validator, uint128 amount);

    /**
     * @notice Emitted when sender removes an amount of BGT boost from a validator
     * @param sender The address of the sender.
     * @param validator The address of the validator to remove boost from.
     * @param amount The amount of BGT boost to remove.
     */
    event DropBoost(address indexed sender, address indexed validator, uint128 amount);

    /// @notice Emitted when the BGT token is redeemed for the native token.
    event Redeem(address indexed from, address indexed receiver, uint256 amount);

    /**
     * @notice Emitted when validator sets their commission rate charged on block reward distribution
     * @param validator The address of the validator charging the commission.
     * @param oldRate The old commission rate charged by the validator.
     * @param newRate The new commission rate charged by the validator.
     */
    event UpdateCommission(address indexed validator, uint256 oldRate, uint256 newRate);

    /**
     * @notice Approve an address to send BGT or approve another address to transfer BGT from it.
     * @dev This can only be called by the governance module.
     * @dev BGT should be soul bound to EOAs and only transferable by approved senders.
     * @param sender The address of the sender.
     * @param approved Whether the sender is approved or not.
     */
    function whitelistSender(address sender, bool approved) external;

    /**
     * @notice Mint BGT to the distributor.
     * @dev This can only be called by the minter address, which is set by governance.
     * @param distributor The address of the distributor.
     * @param amount The amount of BGT to mint.
     */
    function mint(address distributor, uint256 amount) external;

    /**
     * @notice Queues a new boost of the validator with an amount of BGT from `msg.sender`.
     * @dev Reverts if `msg.sender` does not have enough unboosted balance to cover amount.
     * @param validator The address of the validator to be boosted.
     * @param amount The amount of BGT to use for the queued boost.
     */
    function queueBoost(address validator, uint128 amount) external;

    /**
     * @notice Cancels a queued boost of the validator removing an amount of BGT for `msg.sender`.
     * @dev Reverts if `msg.sender` does not have enough queued balance to cover amount.
     * @param validator The address of the validator to cancel boost for.
     * @param amount The amount of BGT to remove from the queued boost.
     */
    function cancelBoost(address validator, uint128 amount) external;

    /**
     * @notice Boost the validator with an amount of BGT from `msg.sender`.
     * @dev Reverts if `msg.sender` does not have enough unboosted balance to cover amount.
     * @param validator The address of the validator to boost.
     */
    function activateBoost(address validator) external;

    /**
     * @notice Drops an amount of BGT from an existing boost of validator by `msg.sender`.
     * @param validator The address of the validator to remove boost from.
     * @param amount The amount of BGT to remove from the boost.
     */
    function dropBoost(address validator, uint128 amount) external;

    /**
     * @notice Sets the commission rate on block rewards to be charged by validator.
     * @dev Reverts if not called by either validator or operator of validator.
     * @param validator The address of the validator to set the commission rate for.
     * @param reward The new reward rate to charge as commission.
     */
    function setCommission(address validator, uint256 reward) external;

    /**
     * @notice Returns the amount of BGT queued up to be used by an account to boost a validator.
     * @param account The address of the account boosting.
     * @param validator The address of the validator being boosted.
     */
    function boostedQueue(
        address account,
        address validator
    )
        external
        view
        returns (uint32 blockNumberLast, uint128 balance);

    /**
     * @notice Returns the amount of BGT queued up to be used by an account for boosts.
     * @param account The address of the account boosting.
     */
    function queuedBoost(address account) external view returns (uint128);

    /**
     * @notice Returns the amount of BGT used by an account to boost a validator.
     * @param account The address of the account boosting.
     * @param validator The address of the validator being boosted.
     */
    function boosted(address account, address validator) external view returns (uint128);

    /**
     * @notice Returns the amount of BGT used by an account for boosts.
     * @param account The address of the account boosting.
     */
    function boosts(address account) external view returns (uint128);

    /**
     * @notice Returns the amount of BGT attributed to the validator for boosts.
     * @param validator The address of the validator being boosted.
     */
    function boostees(address validator) external view returns (uint128);

    /**
     * @notice Returns the total boosts for all validators.
     */
    function totalBoosts() external view returns (uint128);

    /**
     * @notice Returns the commission rate charged by the validator on new block rewards.
     * @param validator The address of the validator charging the commission rate.
     */
    function commissions(address validator) external view returns (uint32 blockTimestampLast, uint224 rate);

    /**
     * @notice Returns the scaled reward rate for the validator given outstanding boosts.
     * @dev Used by distributor to distribute BGT rewards.
     * @param validator The address of the boosted validator.
     * @param rewardRate The unscaled reward rate for the block.
     */
    function boostedRewardRate(address validator, uint256 rewardRate) external view returns (uint256);

    /**
     * @notice Returns the amount of the reward rate to be dedicated to commissions for the given validator.
     * @dev Used by distributor to distribute BGT rewards.
     * @param validator The address of the validator charging commission.
     * @param rewardRate The reward rate to take commission from for the block.
     */
    function commissionRewardRate(address validator, uint256 rewardRate) external view returns (uint256);

    /**
     * @notice Public variable that represents the caller of the mint method.
     * @dev This is going to be the BlockRewardController contract at first.
     */
    function minter() external view returns (address);

    /**
     * @notice Set the minter address.
     * @dev This can only be called by the governance module.
     * @param _minter The address of the minter.
     */
    function setMinter(address _minter) external;

    /**
     * @notice Set the BeraChef address.
     * @param _beraChef The address of the BeraChef contract.
     * @dev OnlyOwner can call.
     */
    function setBeraChef(address _beraChef) external;

    /**
     * @notice Redeem the BGT token for the native token at a 1:1 rate.
     * @param receiver The receiver's address who will receive the native token.
     * @param amount The amount of BGT to redeem.
     */
    function redeem(address receiver, uint256 amount) external;

    /**
     * @notice Returns the unboosted balance of an account.
     * @param account The address of the account.
     */
    function unboostedBalanceOf(address account) external view returns (uint256);
}
