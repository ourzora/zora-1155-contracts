// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ZoraCreator1155FactoryImpl} from "@zoralabs/zora-1155-contracts/src/factory/ZoraCreator1155FactoryImpl.sol";
import {ZoraCreator1155PremintExecutorImpl} from "@zoralabs/zora-1155-contracts/src/delegation/ZoraCreator1155PremintExecutorImpl.sol";
import {ForkDeploymentConfig, Deployment, ChainConfig} from "../src/DeploymentConfig.sol";
import {ZoraDeployerUtils} from "../src/ZoraDeployerUtils.sol";
import {DeploymentTestingUtils} from "../src/DeploymentTestingUtils.sol";
import {IZoraCreator1155PremintExecutor} from "@zoralabs/zora-1155-contracts/src/interfaces/IZoraCreator1155PremintExecutor.sol";

contract UpgradesTest is ForkDeploymentConfig, DeploymentTestingUtils, Test {
    /// @notice gets the chains to do fork tests on, by reading environment var FORK_TEST_CHAINS.
    /// Chains are by name, and must match whats under `rpc_endpoints` in the foundry.toml
    function getForkTestChains() private view returns (string[] memory result) {
        try vm.envString("FORK_TEST_CHAINS", ",") returns (string[] memory forkTestChains) {
            result = forkTestChains;
        } catch {
            console.log("could not get fork test chains - make sure the environment variable FORK_TEST_CHAINS is set");
            result = new string[](0);
        }
    }

    function determine1155Upgrade(Deployment memory deployment) private view returns (bool upgradeNeeded, address targetProxy, address targetImpl) {
        targetProxy = deployment.factoryProxy;
        targetImpl = deployment.factoryImpl;
        address currentImplementation = ZoraCreator1155FactoryImpl(targetProxy).implementation();

        upgradeNeeded = targetImpl != currentImplementation;
    }

    function determinePreminterUpgrade(Deployment memory deployment) private pure returns (bool upgradeNeeded, address targetProxy, address targetImpl) {
        targetProxy = deployment.preminterProxy;
        targetImpl = deployment.preminterImpl;

        // right now we cannot call "implementation" on contract since it doesn't exist yet, so we check if deployed impl meets the v1 impl we know
        address preminterV1ImplAddress = 0x6E2AbBcd82935bFC68A1d5d2c96372b13b65eD9C;

        upgradeNeeded = targetImpl != preminterV1ImplAddress;
    }

    /// @notice checks which chains need an upgrade, simulated the upgrade, and gets the upgrade calldata
    function simulateUpgradeOnFork(string memory chainName) private {
        // create and select the fork, which will be used for all subsequent calls
        vm.createSelectFork(vm.rpcUrl(chainName));

        Deployment memory deployment = getDeployment();

        ChainConfig memory chainConfig = getChainConfig();

        address creator = makeAddr("creator");

        (bool is1155UpgradeNeeded, address targetProxy1155, address targetImpl1155) = determine1155Upgrade(deployment);
        (bool preminterUpgradeNeeded, address targetPreminterProxy, address targetPremintImpl) = determinePreminterUpgrade(deployment);

        if (!is1155UpgradeNeeded && !preminterUpgradeNeeded) {
            return;
        }

        console2.log("====== upgrade needed ======");
        console2.log("chain:", chainName);
        console2.log("upgrade owner:", chainConfig.factoryOwner);

        if (is1155UpgradeNeeded) {
            console2.log("-- 1155 upgrade needed --");
            vm.prank(chainConfig.factoryOwner);
            bytes memory factory1155UpgradeCalldata = ZoraDeployerUtils.simulateUpgrade(targetProxy1155, targetImpl1155);
            vm.prank(creator);
            ZoraDeployerUtils.deployTestContractForVerification(targetProxy1155, creator);

            console2.log("1155 upgrade target:", targetProxy1155);
            console2.log("upgrade calldata:");
            console.logBytes(factory1155UpgradeCalldata);
            console2.log("upgrade to address:", targetImpl1155);
            console2.log("upgrade to version:", ZoraCreator1155FactoryImpl(targetImpl1155).contractVersion());
            console2.log("------------------------");
        }

        // hack - for now, only check on zora sepolia or goerli
        if (preminterUpgradeNeeded) {
            console2.log("-- preminter upgrade needed --");
            console2.log("preminter upgrade target:", targetPreminterProxy);
            vm.prank(chainConfig.factoryOwner);
            bytes memory preminterUpgradeCalldata = ZoraDeployerUtils.simulateUpgrade(deployment.preminterProxy, deployment.preminterImpl);

            address collector = makeAddr("collector");
            address mintReferral = makeAddr("referral");
            vm.deal(collector, 10 ether);

            IZoraCreator1155PremintExecutor.MintArguments memory mintArguments = IZoraCreator1155PremintExecutor.MintArguments({
                mintRecipient: collector,
                mintComment: "",
                mintReferral: mintReferral
            });

            vm.startPrank(collector);
            signAndExecutePremintV1(targetPreminterProxy, makeAddr("payoutRecipientA"), mintArguments);
            signAndExecutePremintV2(targetPreminterProxy, makeAddr("payoutRecipientB"), mintArguments);

            console2.log("upgrade calldata:");
            console.logBytes(preminterUpgradeCalldata);
            console2.log("upgrade to address:", targetPremintImpl);
            console2.log("------------------------");
        }

        console2.log("=================\n");
    }

    function test_fork_simulateUpgrades() external {
        string[] memory forkTestChains = getForkTestChains();
        for (uint256 i = 0; i < forkTestChains.length; i++) {
            simulateUpgradeOnFork(forkTestChains[i]);
        }
    }
}
