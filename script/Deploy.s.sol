// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";

contract Deploy is Script {
    function run() public {
        uint256 pkey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.rememberKey(pkey);

        vm.createSelectFork(getChain("goerli").rpcUrl);

        vm.broadcast(deployer);
        XXYYZZ test = new XXYYZZ(deployer, 10_000, true);
        uint256 mintPrice = test.MINT_PRICE();

        vm.broadcast(deployer);
        test.mint{value: mintPrice}();
    }
}
