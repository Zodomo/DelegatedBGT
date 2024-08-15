// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { FixedPointMathLib } from "solady/src/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";

import { Utils } from "../libraries/Utils.sol";
import { IPOLErrors } from "./interfaces/IPOLErrors.sol";
import { StakingRewards } from "./rewards/StakingRewards.sol";

/// @title BGTStaker
/// @author Berachain Team
contract BGTStaker is OwnableUpgradeable, UUPSUpgradeable, StakingRewards {
    using Utils for bytes4;
    using SafeTransferLib for address;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Emitted when a token has been recovered.
    /// @param token The token that has been recovered.
    /// @param amount The amount of token recovered.
    event Recovered(address token, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The fee collector contract that is allowed to notify rewards.
    address public FEE_COLLECTOR;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         INITIALIZER                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _bgt,
        address _feeCollector,
        address _governance,
        address _rewardToken
    )
        external
        initializer
    {
        __Ownable_init(_governance);
        __StakingRewards_init(_bgt, _rewardToken, 7 days);
        FEE_COLLECTOR = _feeCollector;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier onlyBGT() {
        if (msg.sender != address(STAKE_TOKEN)) NotBGT.selector.revertWith();
        _;
    }

    modifier onlyFeeCollector() {
        if (msg.sender != FEE_COLLECTOR) NotFeeCollector.selector.revertWith();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       ADMIN FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    function notifyRewardAmount(uint256 reward) external onlyFeeCollector {
        _notifyRewardAmount(reward);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        if (tokenAddress == address(REWARD_TOKEN)) CannotRecoverRewardToken.selector.revertWith();
        tokenAddress.safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        _setRewardsDuration(_rewardsDuration);
    }

    function stake(address account, uint256 amount) external onlyBGT {
        _stake(account, amount);
    }

    function withdraw(address account, uint256 amount) external onlyBGT {
        _withdraw(account, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  STATE MUTATING FUNCTIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Claim the reward of the caller.
    function getReward() external returns (uint256) {
        return _getReward(msg.sender, msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Override the internal function to prevent transferring BGT.
    function _safeTransferFromStakeToken(address from, uint256 amount) internal override { }

    /// @dev Override the internal function to prevent transferring BGT.
    function _safeTransferStakeToken(address to, uint256 amount) internal override { }
}
