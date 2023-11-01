// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraDeployerBase} from "@zoralabs/zora-1155-contracts/src/deployment/ZoraDeployerBase.sol";
import {Deployment} from "@zoralabs/zora-1155-contracts/src/deployment/DeploymentConfig.sol";
import {DeterministicDeployerScript} from "@zoralabs/zora-1155-contracts/src/deployment/DeterministicDeployerScript.sol";

/// @dev Deploys preminter implementation contract.
/// @notice Run after deploying the minters
contract DeployPreminterImpl is ZoraDeployerBase {
    function run() public returns (string memory) {
        Deployment memory deployment = getDeployment();

        vm.startBroadcast();

        deployNewPreminterImplementationDeterminstic(deployment);

        return getDeploymentJSON(deployment);
    }
}
