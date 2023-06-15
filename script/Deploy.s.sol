// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";

contract Deploy is Script {
    function run() public {
        vm.createSelectFork(getChain("goerli").rpcUrl);
        uint256 pkey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.rememberKey(pkey);
        address creatorPayout = 0x7ade04fa0cbE2167E8bff758F48879BD0C6fFf92;

        uint24[] memory preMints = new uint24[](5);
        preMints[1] = 0xffffff;
        preMints[2] = 0x696969;
        preMints[3] = 0xff6000;
        preMints[4] = 0x00ff00;
        address seaDrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

        vm.createSelectFork(getChain("goerli").rpcUrl);

        vm.broadcast(deployer);
        XXYYZZ test = new XXYYZZ(deployer,creatorPayout, 5, preMints,seaDrop);
        uint256 mintPrice = test.MINT_PRICE();

        vm.broadcast(deployer);
        test.configureSeaDrop();

        vm.broadcast(deployer);
        test.mint{value: mintPrice}();
    }
}
