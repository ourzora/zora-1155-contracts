// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraDeployerBase} from "./ZoraDeployerBase.sol";
import {ZoraDeployerUtils} from "../src/deployment/ZoraDeployerUtils.sol";
import {ChainConfig, Deployment} from "../src/deployment/DeploymentConfig.sol";

import {ZoraCreator1155FactoryImpl} from "../src/factory/ZoraCreator1155FactoryImpl.sol";
import {Zora1155Factory} from "../src/proxies/Zora1155Factory.sol";
import {ZoraCreator1155Impl} from "../src/nft/ZoraCreator1155Impl.sol";
import {IZoraCreator1155Factory} from "../src/interfaces/IZoraCreator1155Factory.sol";
import {IZoraCreator1155} from "../src/interfaces/IZoraCreator1155.sol";
import {DeterministicDeployerScript} from "../src/deployment/DeterministicDeployerScript.sol";
import {IMinter1155} from "../src/interfaces/IMinter1155.sol";
import {DeploymentTestingUtils} from "../src/deployment/DeploymentTestingUtils.sol";

contract DeployAllToNewChain is ZoraDeployerBase, DeterministicDeployerScript, DeploymentTestingUtils {
    function run() public returns (string memory) {
        Deployment memory deployment = getDeployment();
        ChainConfig memory chainConfig = getChainConfig();

        address deployer = vm.envAddress("DEPLOYER");

        // Sanity check to make sure that the factory owner is a smart contract.
        // This may catch cross-chain data copy mistakes where there is no safe at the desired admin address.
        if (address(chainConfig.factoryOwner).code.length == 0) {
            revert("FactoryOwner should be a contract. See DeployNewProxies:31.");
        }

        uint256 chain = chainId();

        vm.startBroadcast(deployer);

        (address fixedPriceMinter, address merkleMinter, address redeemMinterFactory) = ZoraDeployerUtils.deployMinters();

        console.log("deploy upgrade gate");

        address upgradeGateAddress = deployUpgradeGate({chain: chainId(), upgradeGateOwner: chainConfig.factoryOwner});

        console.log("impl contracts");

        (address factoryImplAddress, address contract1155ImplAddress) = ZoraDeployerUtils.deployNew1155AndFactoryImpl(
            upgradeGateAddress,
            chainConfig.mintFeeRecipient,
            chainConfig.protocolRewards,
            IMinter1155(merkleMinter),
            IMinter1155(redeemMinterFactory),
            IMinter1155(fixedPriceMinter)
        );

        console.log("deploy factory proxy");

        address factoryProxyAddress = deployDeterministicProxy({
            proxyName: "factoryProxy",
            implementation: deployment.factoryImpl,
            owner: chainConfig.factoryOwner,
            chain: chain
        });

        console2.log("create test contract for verification");

        ZoraDeployerUtils.deployTestContractForVerification(factoryProxyAddress, makeAddr("admin"));

        console2.log("Deployed new contract for verification purposes");

        console2.log("deploy preminter and proxy");

        address preminterImpl = ZoraDeployerUtils.deployNewPreminterImplementationDeterminstic(address(factoryProxyAddress));

        address preminterProxyAddress = deployDeterministicProxy({
            proxyName: "premintExecutorProxy",
            implementation: deployment.preminterImpl,
            owner: chainConfig.factoryOwner,
            chain: chain
        });

        deployment.fixedPriceSaleStrategy = address(fixedPriceMinter);
        deployment.merkleMintSaleStrategy = address(merkleMinter);
        deployment.redeemMinterFactory = address(redeemMinterFactory);
        deployment.upgradeGate = upgradeGateAddress;
        deployment.factoryImpl = factoryImplAddress;
        deployment.contract1155Impl = contract1155ImplAddress;
        deployment.factoryProxy = factoryProxyAddress;
        deployment.preminterImpl = preminterImpl;
        deployment.preminterProxy = preminterProxyAddress;

        console2.log("testing premint");

        signAndExecutePremint(preminterProxyAddress);

        vm.stopBroadcast();

        // now test signing and executing premint

        return getDeploymentJSON(deployment);
    }
}
