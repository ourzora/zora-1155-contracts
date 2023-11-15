// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Zora1155FactoryFixtures} from "../fixtures/Zora1155FactoryFixtures.sol";
import {Zora1155PremintFixtures} from "../fixtures/Zora1155PremintFixtures.sol";
import {ZoraCreator1155FactoryImpl} from "../../src/factory/ZoraCreator1155FactoryImpl.sol";
import {Zora1155PremintExecutor} from "../../src/proxies/Zora1155PremintExecutor.sol";
import {ZoraCreator1155Impl} from "../../src/nft/ZoraCreator1155Impl.sol";
import {ZoraCreator1155PremintExecutorImpl} from "../../src/delegation/ZoraCreator1155PremintExecutorImpl.sol";
import {Zora1155Factory} from "../../src/proxies/Zora1155Factory.sol";
import {IMinter1155} from "../../src/interfaces/IMinter1155.sol";
import {ProxyShim} from "../../src/utils/ProxyShim.sol";
import {ZoraCreator1155Attribution, ContractCreationConfig, TokenCreationConfigV2, PremintConfigV2} from "../../src/delegation/ZoraCreator1155Attribution.sol";
import {IOwnable2StepUpgradeable} from "../../src/utils/ownable/IOwnable2StepUpgradeable.sol";
import {IHasContractName} from "../../src/interfaces/IContractMetadata.sol";
import {ZoraCreator1155PremintExecutorImplLib} from "../../src/delegation/ZoraCreator1155PremintExecutorImplLib.sol";
import {IZoraCreator1155PremintExecutor} from "../../src/interfaces/IZoraCreator1155PremintExecutor.sol";

contract Zora1155PremintExecutorProxyTest is Test, IHasContractName {
    address internal owner;
    uint256 internal creatorPrivateKey;
    address internal creator;
    address internal collector;
    address internal zora;
    Zora1155Factory internal factoryProxy;
    ZoraCreator1155FactoryImpl factoryAtProxy;
    uint256 internal mintFeeAmount = 0.000777 ether;
    ZoraCreator1155PremintExecutorImpl preminterAtProxy;

    IZoraCreator1155PremintExecutor.MintArguments defaultMintArguments;

    function setUp() external {
        zora = makeAddr("zora");
        owner = makeAddr("owner");
        collector = makeAddr("collector");
        (creator, creatorPrivateKey) = makeAddrAndKey("creator");

        vm.startPrank(zora);
        (, , factoryProxy) = Zora1155FactoryFixtures.setup1155AndFactoryProxy(zora, zora);
        factoryAtProxy = ZoraCreator1155FactoryImpl(address(factoryProxy));
        vm.stopPrank();

        // create preminter implementation
        ZoraCreator1155PremintExecutorImpl preminterImplementation = new ZoraCreator1155PremintExecutorImpl(ZoraCreator1155FactoryImpl(address(factoryProxy)));

        // build the proxy
        Zora1155PremintExecutor proxy = new Zora1155PremintExecutor(address(preminterImplementation), "");

        // access the executor implementation via the proxy, and initialize the admin
        preminterAtProxy = ZoraCreator1155PremintExecutorImpl(address(proxy));
        preminterAtProxy.initialize(owner);

        defaultMintArguments = IZoraCreator1155PremintExecutor.MintArguments({mintRecipient: collector, mintComment: "blah", mintReferral: address(0)});
    }

    function test_canInvokeImplementationMethods() external {
        // create premint config
        IMinter1155 fixedPriceMinter = ZoraCreator1155FactoryImpl(address(factoryProxy)).fixedPriceMinter();

        PremintConfigV2 memory premintConfig = PremintConfigV2({
            tokenConfig: Zora1155PremintFixtures.makeDefaultTokenCreationConfigV2(fixedPriceMinter, creator),
            uid: 100,
            version: 0,
            deleted: false
        });

        // now interface with proxy preminter - sign and execute the premint
        ContractCreationConfig memory contractConfig = Zora1155PremintFixtures.makeDefaultContractCreationConfig(creator);
        address deterministicAddress = preminterAtProxy.getContractAddress(contractConfig);

        // sign the premint
        bytes32 structHash = ZoraCreator1155Attribution.hashPremint(premintConfig);
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(
            structHash,
            deterministicAddress,
            ZoraCreator1155Attribution.HASHED_VERSION_2,
            block.chainid
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, digest);

        uint256 quantityToMint = 1;

        bytes memory signature = abi.encodePacked(r, s, v);

        // execute the premint
        vm.deal(collector, mintFeeAmount);
        vm.prank(collector);
        uint256 tokenId = preminterAtProxy
        .premintV2{value: mintFeeAmount}(contractConfig, premintConfig, signature, quantityToMint, defaultMintArguments).tokenId;

        assertEq(ZoraCreator1155Impl(deterministicAddress).balanceOf(collector, tokenId), 1);
    }

    function test_onlyOwnerCanUpgrade() external {
        // try to upgrade as non-owner
        ZoraCreator1155PremintExecutorImpl newImplementation = new ZoraCreator1155PremintExecutorImpl(factoryAtProxy);

        vm.expectRevert(IOwnable2StepUpgradeable.ONLY_OWNER.selector);
        vm.prank(creator);
        preminterAtProxy.upgradeTo(address(newImplementation));
    }

    /// giving this a contract name so that it can be used to fail upgrading preminter contract
    function contractName() public pure returns (string memory) {
        return "Test Contract";
    }

    function test_canOnlyBeUpgradedToContractWithSameName() external {
        // upgrade to bad contract with has wrong name (this contract has mismatched name)
        vm.expectRevert(
            abi.encodeWithSelector(ZoraCreator1155PremintExecutorImpl.UpgradeToMismatchedContractName.selector, preminterAtProxy.contractName(), contractName())
        );
        vm.prank(owner);
        preminterAtProxy.upgradeTo(address(this));

        // upgrade to good contract which has correct name - it shouldn't revert
        ZoraCreator1155PremintExecutorImpl newImplementation = new ZoraCreator1155PremintExecutorImpl(ZoraCreator1155FactoryImpl(address(factoryProxy)));

        vm.prank(owner);
        preminterAtProxy.upgradeTo(address(newImplementation));
    }
}
