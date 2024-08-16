// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BGT} from "../src/pol/BGT.sol";
import {DelegateRegistry} from "delegate-registry/src/DelegateRegistry.sol";

contract DelegatedBGTTest is Test {
    BGT bgt;
    DelegateRegistry registry;
    address owner;
    address delegator;
    address delegate;
    address validator;

    modifier prank(address addr) {
        vm.startPrank(addr);
        _;
        vm.stopPrank();
    }

    // Overwrite BGT contract with our version and initialize `registry`
    function prepare() public {
        bgt = new BGT();
        bgt.initialize(owner);
        vm.etch(0xbDa130737BDd9618301681329bF2e46A016ff9Ad, address(bgt).code);
        bgt = BGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
        registry = DelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);
    }

    function delegation() public prank(delegator) {
        registry.delegateAll(delegate, bytes32(''), true);
    }

    function mint() public prank(bgt.minter()) {
        bgt.mint(delegator, 1 ether);
    }

    function queue() public prank(delegate) {
        bgt.queueBoost(delegator, validator, 1 ether);
    }

    function cancel() public prank(delegate) {
        bgt.cancelBoost(delegator, validator, 1 ether);
    }

    function activate() public prank(delegate) {
        bgt.activateBoost(delegator, validator);
    }

    function drop() public prank(delegate) {
        bgt.dropBoost(delegator, validator, 1 ether);
    }

    function setUp() public {
        owner = makeAddr("owner");
        delegator = makeAddr("delegator");
        delegate = makeAddr("delegate");
        validator = makeAddr("validator");
        vm.createSelectFork("testnet");
        prepare();
        delegation();
        mint();
    }

    function testQueue() public {
        queue();
    }

    function testCancel() public {
        queue();
        cancel();
    }

    function testActivate() public {
        queue();
        vm.roll(block.number + 8192);
        activate();
    }

    function testDrop() public {
        queue();
        activate();
        drop();
    }
}