// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BGT} from "../src/pol/BGT.sol";
import {DelegateRegistry} from "delegate-registry/src/DelegateRegistry.sol";

contract DelegatedBGTTest is Test {
    BGT bgt;
    DelegateRegistry registry;
    address owner = 0x8a73D1380345942F1cb32541F1b19C40D8e6C94B;
    address delegator = 0x9a085B397b12A2ff95759fE3a26518f934a03123;
    address validator = 0x2D764DFeaAc00390c69985631aAA7Cc3fcfaFAfF;
    address delegate;
    uint128 unboosted;

    modifier prank(address addr) {
        vm.startPrank(addr);
        _;
        vm.stopPrank();
    }

    function setUp() public {        
        delegate = makeAddr("delegate");
        vm.createSelectFork("testnet");
        prepare();
        delegation();
    }

    // Overwrite BGT contract with our version and initialize `registry`
    function prepare() public {
        vm.roll(2995083);
        bgt = new BGT();
        bgt.initialize(owner);
        vm.etch(0xbDa130737BDd9618301681329bF2e46A016ff9Ad, address(bgt).code);
        bgt = BGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
        unboosted = uint128(bgt.unboostedBalanceOf(delegator));
        registry = DelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);
    }

    function delegation() public prank(delegator) {
        registry.delegateAll(delegate, bytes32(''), true);
    }

    /*function mint() public prank(bgt.minter()) {
        bgt.mint(delegator, 1 ether);
    }*/

    function queue(uint128 amount) public prank(delegate) {
        bgt.queueBoost(delegator, validator, amount);
    }

    function cancel(uint128 amount) public prank(delegate) {
        bgt.cancelBoost(delegator, validator, amount);
    }

    function activate() public prank(delegate) {
        bgt.activateBoost(delegator, validator);
    }

    function drop(uint128 amount) public prank(delegate) {
        bgt.dropBoost(delegator, validator, amount);
    }

    function testQueue() public {
        queue(unboosted);
    }

    function testCancel() public {
        queue(unboosted);
        cancel(unboosted);
    }

    // TODO: Identify why activateBoost throws `EvmError: NotActivated`
    function testActivate() public {
        queue(unboosted);
        vm.roll(3003275);
        activate();
    }

    /*function testDrop() public {
        queue(unboosted);
        vm.roll(3003275);
        activate();
        drop(unboosted);
    }*/
}