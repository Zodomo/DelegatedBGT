// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BGT} from "../src/pol/BGT.sol";
import {DelegateRegistry} from "delegate-registry/src/DelegateRegistry.sol";

contract DelegatedBGTTest is Test {
    BGT bgt;
    DelegateRegistry registry;
    //address owner = 0x8a73D1380345942F1cb32541F1b19C40D8e6C94B;
    address delegator = 0x9a085B397b12A2ff95759fE3a26518f934a03123;
    address validator = 0x2D764DFeaAc00390c69985631aAA7Cc3fcfaFAfF;
    address delegate;

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
        // NOTE: Etch currently seems to overwrite storage too, is there a way to only upgrade code?
        bgt = new BGT();
        vm.etch(0xbDa130737BDd9618301681329bF2e46A016ff9Ad, address(bgt).code);
        bgt = BGT(0xbDa130737BDd9618301681329bF2e46A016ff9Ad);
        registry = DelegateRegistry(0x00000000000000447e69651d841bD8D104Bed493);
    }

    function delegation() public prank(delegator) {
        registry.delegateAll(delegate, bytes32(''), true);
    }

    /*function mint() public prank(bgt.minter()) {
        bgt.mint(delegator, 1 ether);
    }*/

    function queue() public prank(delegate) {
        bgt.queueBoost(delegator, validator, 64900877015889774);
    }

    function cancel() public prank(delegate) {
        bgt.cancelBoost(delegator, validator, 64900877015889774);
    }

    function activate() public prank(delegate) {
        bgt.activateBoost(delegator, validator);
    }

    function drop() public prank(delegate) {
        bgt.dropBoost(delegator, validator, 64900877015889774);
    }

    function testQueue() public {
        vm.roll(2995082);
        queue();
    }

    /*function testCancel() public {
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
    }*/
}