// SPDX-License-Identifier: MIT
// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

library Utils {
    /// @dev Reverts with the selector of a custom error in the scratch space.
    function revertWith(bytes4 selector) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, selector)
            revert(0, 0x04)
        }
    }

    /// @dev Reverts for the reason encoding a silent revert, Error(string), or a custom error.
    function revertFor(bytes memory reason) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            revert(add(reason, 0x20), mload(reason))
        }
    }

    function revertWith(bytes4 selector, address addr) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, selector)
            mstore(0x04, addr)
            revert(0, 0x24) // 4 (selector) + 32 (addr)
        }
    }

    function revertWith(bytes4 selector, uint256 amount) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, selector)
            mstore(0x04, amount)
            revert(0, 0x24) // 4 (selector) + 32 (amount)
        }
    }

    function revertWith(bytes4 selector, uint256 amount1, uint256 amount2) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, selector)
            mstore(0x04, amount1)
            mstore(0x24, amount2)
            revert(0, 0x44) // 4 (selector) + 32 (amount1) + 32 (amount2)
        }
    }

    function revertWith(bytes4 selector, address addr1, address addr2) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, selector)
            mstore(0x04, addr1)
            mstore(0x24, addr2)
            revert(0, 0x44) // 4 (selector) + 32 (addr1) + 32 (addr2)
        }
    }
}
