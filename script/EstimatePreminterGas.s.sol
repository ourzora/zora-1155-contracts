// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {ZoraDeployerBase} from "./ZoraDeployerBase.sol";
import {ChainConfig, Deployment} from "../src/deployment/DeploymentConfig.sol";

import {ZoraCreator1155FactoryImpl} from "../src/factory/ZoraCreator1155FactoryImpl.sol";
import {Zora1155Factory} from "../src/proxies/Zora1155Factory.sol";
import {ZoraCreator1155Impl} from "../src/nft/ZoraCreator1155Impl.sol";
import {ICreatorRoyaltiesControl} from "../src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "../src/interfaces/IZoraCreator1155Factory.sol";
import {IMinter1155} from "../src/interfaces/IMinter1155.sol";
import {IZoraCreator1155} from "../src/interfaces/IZoraCreator1155.sol";
import {ProxyShim} from "../src/utils/ProxyShim.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "../src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {ZoraCreatorMerkleMinterStrategy} from "../src/minters/merkle/ZoraCreatorMerkleMinterStrategy.sol";
import {ZoraCreatorRedeemMinterFactory} from "../src/minters/redeem/ZoraCreatorRedeemMinterFactory.sol";
import {ZoraCreator1155Preminter} from "../src/premint/ZoraCreator1155Preminter.sol";

contract EstimatePreminterGas is ZoraDeployerBase {
    function run() public {
        Deployment memory deployment = getDeployment();

        address deployer = vm.envAddress("DEPLOYER");

        ZoraCreator1155FactoryImpl factory = ZoraCreator1155FactoryImpl(deployment.factoryProxy);

        console.log("deploying preminter contract");
        vm.startBroadcast(deployer);

        ZoraCreator1155Preminter preminter = new ZoraCreator1155Preminter();
        preminter.initialize(factory);

        vm.stopBroadcast();

        // now generate a signature

        ZoraCreator1155Preminter.ContractCreationConfig memory contractConfig = ZoraCreator1155Preminter.ContractCreationConfig({
            contractAdmin: deployer,
            contractName: "blah",
            contractURI: "blah.contract"
        });
        // configuration of token to create
        ZoraCreator1155Preminter.TokenCreationConfig memory tokenConfig = ZoraCreator1155Preminter.TokenCreationConfig({
            tokenURI: "blah.token",
            maxSupply: 10,
            maxTokensPerAddress: 5,
            pricePerToken: 0,
            mintStart: 0,
            mintDuration: 365 days,
            royaltyBPS: 10,
            royaltyRecipient: deployer,
            royaltyMintSchedule: 20
        });
        // how many tokens are minted to the executor
        uint256 quantityToMint = 1;
        uint32 uid = 100;
        uint32 version = 0;
        ZoraCreator1155Preminter.PremintConfig memory premintConfig = ZoraCreator1155Preminter.PremintConfig({
            contractConfig: contractConfig,
            tokenConfig: tokenConfig,
            uid: uid,
            deleted: false,
            version: version
        });

        uint256 valueToSend = quantityToMint * ZoraCreator1155Impl(address(factory.implementation())).mintFee();

        bytes32 digest = preminter.premintHashData(premintConfig, address(preminter), chainId());

        uint256 privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        string memory comment = "we love it!";

        console.log("executing premint");
        // now do an on-chain premint
        vm.startBroadcast(deployer);

        preminter.premint{value: valueToSend}(premintConfig, signature, quantityToMint, comment);

        vm.stopBroadcast();
    }
}
