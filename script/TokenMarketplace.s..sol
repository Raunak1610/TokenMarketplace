// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.34;

import {Script} from "forge-std/Script.sol";
import {TokenMarketplace} from "../src/TokenMarketplace.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract TokenMarketplaceScript is Script {
    function run() public {

         HelperConfig helperConfig=new HelperConfig();
         HelperConfig.Networking memory config=helperConfig.getConfig();
    
        vm.startBroadcast();
        TokenMarketplace tokenMarketplace=new TokenMarketplace(config.initialOwner,config.slvToken);
        vm.stopBroadcast();
    }
}


