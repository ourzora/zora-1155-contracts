// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraDeployerBase} from "@zoralabs/zora-1155-contracts/src/deployment/ZoraDeployerBase.sol";
import {Deployment} from "@zoralabs/zora-1155-contracts/src/deployment/DeploymentConfig.sol";
import {ZoraDeployerUtils} from "@zoralabs/zora-1155-contracts/src/deployment/ZoraDeployerUtils.sol";
import {DeploymentTestingUtils} from "@zoralabs/zora-1155-contracts/src/deployment/DeploymentTestingUtils.sol";
import {DeterministicDeployerScript} from "@zoralabs/zora-1155-contracts/src/deployment/DeterministicDeployerScript.sol";

contract DeployUpgradeGate is ZoraDeployerBase {
    function run() public returns (string memory) {
        Deployment memory deployment = getDeployment();

        vm.startBroadcast();

        deployUpgradeGateDeterminstic(deployment);

        vm.stopBroadcast();

        // now test signing and executing premint

        return getDeploymentJSON(deployment);
    }
}
