// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Chain configuration for constants set manually during deploy. Does not get written to after deploys.
struct ChainConfig {
    /// @notice The user that owns the factory proxy. Allows ability to upgrade for new implementations deployed.
    address factoryOwner;
    /// @notice Mint fee amount in WEI charged for each mint
    uint256 mintFeeAmount;
    /// @notice Mint fee recipient user
    address mintFeeRecipient;
    /// @notice Protocol rewards contract address
    address protocolRewards;
}

/// @notice Deployment addresses – set to new deployed addresses by the scripts.
struct Deployment {
    /// @notice Fixed price minter strategy configuration contract
    address fixedPriceSaleStrategy;
    /// @notice Merkle minter strategy (formerly presale) configuration
    address merkleMintSaleStrategy;
    /// @notice Redeem minter factory contract for redeem sales configurations
    address redeemMinterFactory;
    /// @notice Implementation contract for the 1155 contract
    address contract1155Impl;
    /// @notice Implementation contract version for the 1155 contract
    string contract1155ImplVersion;
    /// @notice Factory implementation contract that is the impl for the above proxy.
    address factoryImpl;
    /// @notice Factory proxy contract that creates zora drops style NFT contracts
    address factoryProxy;
    /// @notice Preminter contract address
    address preminter;
    /// @notice UpgradeGate
    address upgradeGate;
}

abstract contract DeploymentConfig is CommonBase {
    using stdJson for string;

    /// @notice ChainID convenience getter
    /// @return id chainId
    function chainId() internal view virtual returns (uint256 id);

    ///
    // These are the JSON key constants to standardize writing and reading configuration
    ///

    string constant FACTORY_OWNER = "FACTORY_OWNER";
    string constant MINT_FEE_AMOUNT = "MINT_FEE_AMOUNT";
    string constant MINT_FEE_RECIPIENT = "MINT_FEE_RECIPIENT";
    string constant PROTOCOL_REWARDS = "PROTOCOL_REWARDS";

    string constant FIXED_PRICE_SALE_STRATEGY = "FIXED_PRICE_SALE_STRATEGY";
    string constant MERKLE_MINT_SALE_STRATEGY = "MERKLE_MINT_SALE_STRATEGY";
    string constant REDEEM_MINTER_FACTORY = "REDEEM_MINTER_FACTORY";
    string constant CONTRACT_1155_IMPL = "CONTRACT_1155_IMPL";
    string constant CONTRACT_1155_IMPL_VERSION = "CONTRACT_1155_IMPL_VERSION";
    string constant FACTORY_IMPL = "FACTORY_IMPL";
    string constant FACTORY_PROXY = "FACTORY_PROXY";
    string constant PREMINTER = "PREMINTER";
    string constant UPGRADE_GATE = "UPGRADE_GATE"; 

    /// @notice Return a prefixed key for reading with a ".".
    /// @param key key to prefix
    /// @return prefixed key
    function getKeyPrefix(string memory key) internal pure returns (string memory) {
        return string.concat(".", key);
    }

    /// @notice Returns the chain configuration struct from the JSON configuration file
    /// @return chainConfig structure
    function getChainConfig() internal view returns (ChainConfig memory chainConfig) {
        string memory json = vm.readFile(string.concat("chainConfigs/", Strings.toString(chainId()), ".json"));
        chainConfig.factoryOwner = json.readAddress(getKeyPrefix(FACTORY_OWNER));
        chainConfig.mintFeeAmount = json.readUint(getKeyPrefix(MINT_FEE_AMOUNT));
        chainConfig.mintFeeRecipient = json.readAddress(getKeyPrefix(MINT_FEE_RECIPIENT));
        chainConfig.protocolRewards = json.readAddress(getKeyPrefix(PROTOCOL_REWARDS));
    }

    function readAddressOrDefaultToZero(string memory json, string memory key) internal view returns (address addr) {
        string memory keyPrefix = getKeyPrefix(key);

        if (vm.keyExists(json, keyPrefix)) {
            addr = json.readAddress(keyPrefix);
        } else {
            addr = address(0);
        }
    }

    /// @notice Get the deployment configuration struct from the JSON configuration file
    /// @return deployment deployment configuration structure
    function getDeployment() internal view returns (Deployment memory deployment) {
        string memory json = vm.readFile(string.concat("addresses/", Strings.toString(chainId()), ".json"));
        deployment.fixedPriceSaleStrategy = readAddressOrDefaultToZero(json, FIXED_PRICE_SALE_STRATEGY);
        deployment.merkleMintSaleStrategy = readAddressOrDefaultToZero(json, MERKLE_MINT_SALE_STRATEGY);
        deployment.redeemMinterFactory = readAddressOrDefaultToZero(json, REDEEM_MINTER_FACTORY);
        deployment.contract1155Impl = readAddressOrDefaultToZero(json, CONTRACT_1155_IMPL);
        deployment.contract1155ImplVersion = json.readString(getKeyPrefix(CONTRACT_1155_IMPL_VERSION));
        deployment.factoryImpl = readAddressOrDefaultToZero(json, FACTORY_IMPL);
        deployment.factoryProxy = readAddressOrDefaultToZero(json, FACTORY_PROXY);
        deployment.preminter = readAddressOrDefaultToZero(json, PREMINTER);
        deployment.upgradeGate = readAddressOrDefaultToZero(json, UPGRADE_GATE);
    }
}

contract ForkDeploymentConfig is DeploymentConfig {
    function chainId() internal view override returns (uint256 id) {
        return block.chainid;
    }
}

contract ScriptDeploymentConfig is DeploymentConfig {
    function chainId() internal view override returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}
