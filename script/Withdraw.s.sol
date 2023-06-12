// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";

contract Withdraw is Script {
    function run() public {
        vm.createSelectFork(getChain("goerli").rpcUrl);
        uint256 pkey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.rememberKey(pkey);
        address payable addy = payable(0x618223b70E5b10B36dd45A8C5B0514D8f487e7b1);
        XXYYZZ xxyyzz = XXYYZZ(addy);
        vm.broadcast(deployer);
        xxyyzz.withdraw();
    }
}
