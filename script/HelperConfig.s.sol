// SPDX-License-Identifier: MIT
pragma solidity =0.8.34;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId(uint256 invalidChainId);
    error HelperConfig__LocalNetworkConfigNotSet();

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address public constant DEFAULT_ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    struct NetworkConfig {
        address initialOwner;
        address slvToken;
    }

    NetworkConfig public localNetworkConfig;

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getEthConfig();
        }

        if (chainId == ETH_MAINNET_CHAIN_ID) {
            return getEthConfig();
        }

        if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilConfig();
        }

        revert HelperConfig__InvalidChainId(chainId);
    }

    function getEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({initialOwner: vm.envAddress("INITIAL_OWNER"), slvToken: vm.envAddress("SLV_TOKEN")});
    }

    function setUpAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.slvToken != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        ERC20Mock slvToken = new ERC20Mock();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            initialOwner: vm.envOr("INITIAL_OWNER", DEFAULT_ANVIL_ACCOUNT), slvToken: address(slvToken)
        });

        return localNetworkConfig;
    }

    function getAnvilConfig() public view returns (NetworkConfig memory) {
        if (localNetworkConfig.slvToken == address(0)) {
            revert HelperConfig__LocalNetworkConfigNotSet();
        }

        return localNetworkConfig;
    }
}