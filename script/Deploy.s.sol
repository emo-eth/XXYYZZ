// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {XXYYZZ} from "../src/XXYYZZ.sol";
import {BaseCreate2Script} from "create2-helpers/script/BaseCreate2Script.s.sol";

contract Deploy is BaseCreate2Script {
    function run() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        super.setUp();
        address creatorPayout = 0x7ade04fa0cbE2167E8bff758F48879BD0C6fFf92;

        uint24[] memory preMints = new uint24[](5);
        preMints[1] = 0xffffff;
        preMints[2] = 0x696969;
        preMints[3] = 0xff6000;
        preMints[4] = 0x00ff00;
        address seaDrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

        bytes memory creationCode = type(XXYYZZ).creationCode;

        creationCode = abi.encodePacked(creationCode, abi.encode(deployer, creatorPayout, 5, preMints, seaDrop));
        console2.logBytes32(keccak256(creationCode)); // 0x441490b1ef05da3b8c59c58dbca8c7a9579225242dc8b957ce506bdd85e970cd
        // starts with FF6000
        uint256 salt = 64744444913995508200752332462249337323357634718575558519965188364118140729719;

        // vm.broadcast(deployer);
        address addy = _create2IfNotDeployed(deployer, bytes32(salt), creationCode);

        // vm.broadcast(deployer);
        XXYYZZ test = XXYYZZ(payable(addy)); //new XXYYZZ(deployer,creatorPayout, 5, preMints,seaDrop);

        vm.broadcast(deployer);
        test.configureSeaDrop();
    }
}
