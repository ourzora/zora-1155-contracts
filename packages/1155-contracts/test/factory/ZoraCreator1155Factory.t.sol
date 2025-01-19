// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {ZoraCreator1155FactoryImpl} from "../../src/factory/ZoraCreator1155FactoryImpl.sol";
import {ZoraCreator1155Impl} from "../../src/nft/ZoraCreator1155Impl.sol";
import {Zora1155Factory} from "../../src/proxies/Zora1155Factory.sol";
import {IZoraCreator1155Factory} from "../../src/interfaces/IZoraCreator1155Factory.sol";
import {IZoraCreator1155} from "../../src/interfaces/IZoraCreator1155.sol";
import {IZoraCreator1155Errors} from "../../src/interfaces/IZoraCreator1155Errors.sol";
import {IMinter1155} from "../../src/interfaces/IMinter1155.sol";
import {ICreatorRoyaltiesControl} from "../../src/interfaces/ICreatorRoyaltiesControl.sol";
import {Zora1155} from "../../src/proxies/Zora1155.sol";
import {UpgradeGate} from "../../src/upgrades/UpgradeGate.sol";
import {MockContractMetadata} from "../mock/MockContractMetadata.sol";
import {ProxyShim} from "../../src/utils/ProxyShim.sol";

contract ZoraCreator1155FactoryTest is Test {
    using stdJson for string;
    address internal zora;

    ZoraCreator1155FactoryImpl internal factoryImpl;
    ZoraCreator1155FactoryImpl internal factory;
    UpgradeGate internal upgradeGate;

    function setUp() external {
        zora = makeAddr("zora");

        upgradeGate = new UpgradeGate();
        upgradeGate.initialize(zora);

        address factoryShimAddress = address(new ProxyShim(zora));
        Zora1155Factory factoryProxy = new Zora1155Factory(factoryShimAddress, "");

        address mockTimedSaleStrategy = makeAddr("timedSaleStrategy");

        ProtocolRewards protocolRewards = new ProtocolRewards();
        ZoraCreator1155Impl zoraCreator1155Impl = new ZoraCreator1155Impl(zora, address(upgradeGate), address(protocolRewards), mockTimedSaleStrategy);

        factoryImpl = new ZoraCreator1155FactoryImpl(zoraCreator1155Impl, IMinter1155(address(1)), IMinter1155(address(2)), IMinter1155(address(3)));
        factory = ZoraCreator1155FactoryImpl(address(factoryProxy));

        vm.startPrank(zora);
        factory.upgradeTo(address(factoryImpl));
        factory.initialize(zora);
        vm.stopPrank();
    }

    function test_contractVersion() external {
        string memory package = vm.readFile("./package.json");
        assertEq(package.readString(".version"), factory.contractVersion());
    }

    function test_contractName() external {
        assertEq(factory.contractName(), "ZORA 1155 Contract Factory");
    }

    function test_contractURI() external {
        assertEq(factory.contractURI(), "https://github.com/ourzora/zora-1155-contracts/");
    }

    function test_initialize(address initialOwner) external {
        vm.assume(initialOwner != address(0));
        address payable proxyAddress = payable(
            address(new Zora1155Factory(address(factoryImpl), abi.encodeWithSelector(ZoraCreator1155FactoryImpl.initialize.selector, initialOwner)))
        );
        ZoraCreator1155FactoryImpl proxy = ZoraCreator1155FactoryImpl(proxyAddress);
        assertEq(proxy.owner(), initialOwner);
    }

    function test_defaultMinters() external {
        IMinter1155[] memory minters = factory.defaultMinters();
        assertEq(minters.length, 3);
        assertEq(address(minters[0]), address(2));
        assertEq(address(minters[1]), address(1));
        assertEq(address(minters[2]), address(3));
    }

    function test_createContract(string memory contractURI, string memory name, uint32 royaltyBPS, address royaltyRecipient, address payable admin) external {
        // If the factory is the admin, the admin flag is cleared
        // during multicall breaking a further test assumption.
        // Additionally, this case makes no sense from a user perspective.
        vm.assume(admin != payable(address(factory)));
        // Assume royalty recipient is not 0
        vm.assume(royaltyRecipient != payable(address(0)));
        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.setupNewToken.selector, "ipfs://asdfadsf", 100);
        address deployedAddress = factory.createContract(
            contractURI,
            name,
            ICreatorRoyaltiesControl.RoyaltyConfiguration({royaltyBPS: royaltyBPS, royaltyRecipient: royaltyRecipient, royaltyMintSchedule: 0}),
            admin,
            initSetup
        );
        ZoraCreator1155Impl target = ZoraCreator1155Impl(payable(deployedAddress));

        ICreatorRoyaltiesControl.RoyaltyConfiguration memory config = target.getRoyalties(0);
        assertEq(config.royaltyMintSchedule, 0);
        assertEq(config.royaltyBPS, royaltyBPS);
        assertEq(config.royaltyRecipient, royaltyRecipient);
        assertEq(target.permissions(0, admin), target.PERMISSION_BIT_ADMIN());
        assertEq(target.uri(1), "ipfs://asdfadsf");
    }

    function test_upgrade(address initialOwner) external {
        vm.assume(initialOwner != address(0));

        IZoraCreator1155 mockNewContract = IZoraCreator1155(address(0x999));

        ZoraCreator1155FactoryImpl newFactoryImpl = new ZoraCreator1155FactoryImpl(
            mockNewContract,
            IMinter1155(address(0)),
            IMinter1155(address(0)),
            IMinter1155(address(0))
        );

        address payable proxyAddress = payable(
            address(new Zora1155Factory(address(factoryImpl), abi.encodeWithSelector(ZoraCreator1155FactoryImpl.initialize.selector, initialOwner)))
        );
        ZoraCreator1155FactoryImpl proxy = ZoraCreator1155FactoryImpl(proxyAddress);
        vm.prank(initialOwner);
        proxy.upgradeTo(address(newFactoryImpl));
        assertEq(address(proxy.zora1155Impl()), address(mockNewContract));
    }

    function test_upgradeFailsWithDifferentContractName(address initialOwner) external {
        vm.assume(initialOwner != address(0));

        MockContractMetadata mockContractMetadata = new MockContractMetadata("ipfs://asdfadsf", "name");

        address payable proxyAddress = payable(
            address(new Zora1155Factory(address(factoryImpl), abi.encodeWithSelector(ZoraCreator1155FactoryImpl.initialize.selector, initialOwner)))
        );
        ZoraCreator1155FactoryImpl proxy = ZoraCreator1155FactoryImpl(proxyAddress);
        vm.prank(initialOwner);
        vm.expectRevert(abi.encodeWithSignature("UpgradeToMismatchedContractName(string,string)", "ZORA 1155 Contract Factory", "name"));
        proxy.upgradeTo(address(mockContractMetadata));
    }

    function test_createContractDeterministic_createsContractAtSameAddressForNameAndUri(
        string calldata nameA,
        string calldata uri,
        address contractAdmin,
        // this number will determine how many transactions the factory makes before
        // creating the deterministic contract.  it should not affect the address
        uint16 numberOfCallsBeforeCreation
    ) external {
        vm.assume(contractAdmin != address(0));
        vm.assume(numberOfCallsBeforeCreation < 5);

        address contractCreator = vm.addr(1);

        // we can know ahead of time the expected address
        address expectedContractAddress = factory.deterministicContractAddress(contractCreator, uri, nameA, contractAdmin);

        // create parameters for contract creation
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });
        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.setupNewToken.selector, "ipfs://asdfadsf", 100);

        // create x number of contracts via the factory, this should affect the nonce.
        for (uint256 i = 0; i < numberOfCallsBeforeCreation; i++) {
            factory.createContract("ipfs://someOtherUri", "someOtherName", royaltyConfig, payable(vm.addr(3)), initSetup);
        }

        // now create deterministically, address should match expected address
        vm.prank(contractCreator);
        address createdAddress = factory.createContractDeterministic(uri, nameA, royaltyConfig, payable(contractAdmin), new bytes[](0));

        assertEq(createdAddress, expectedContractAddress);
    }

    function test_createContractDeterministic_addressIsChangedBySalt(
        string calldata nameA,
        string calldata uri,
        address contractAdmin,
        // this number will determine how transactions the factory makes before
        // creating the deterministic contract.  it should not affect the address
        uint16 numberOfCallsBeforeCreation
    ) external {
        vm.assume(contractAdmin != address(0));
        vm.assume(numberOfCallsBeforeCreation < 5);

        address contractCreator = vm.addr(1);

        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.addPermission.selector, 0, contractCreator, 8);

        // we can know ahead of time the expected address
        address expectedContractAddress = factory.deterministicContractAddressWithSetupActions(contractCreator, uri, nameA, contractAdmin, initSetup);

        // create parameters for contract creation
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });

        vm.prank(contractCreator);
        address createdAddress = factory.createContractDeterministic(uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);

        assertEq(createdAddress, expectedContractAddress);
    }

    function test_createContractDeterministic_createsAndReturnsLastCreated(
        string calldata nameA,
        string calldata uri,
        address contractAdmin,
        // this number will determine how many transactions the factory makes before
        // creating the deterministic contract.  it should not affect the address
        uint16 numberOfCallsBeforeCreation
    ) external {
        vm.assume(contractAdmin != address(0));
        vm.assume(numberOfCallsBeforeCreation < 5);

        address contractCreator = vm.addr(1);

        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.addPermission.selector, 0, contractCreator, 8);

        // we can know ahead of time the expected address
        address expectedContractAddress = factory.deterministicContractAddressWithSetupActions(contractCreator, uri, nameA, contractAdmin, initSetup);

        // create parameters for contract creation
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });

        address[] memory deployments = new address[](2);

        vm.startPrank(contractCreator);
        deployments[0] = factory.createContractDeterministic(uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);
        deployments[1] = factory.getOrCreateContractDeterministic(deployments[0], uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);
        assertEq(deployments[0], deployments[1]);
    }

    function test_createContractDeterministic_createsAndReturnsCreatedBoth(
        string calldata nameA,
        string calldata uri,
        address contractAdmin,
        // this number will determine how many transactions the factory makes before
        // creating the deterministic contract.  it should not affect the address
        uint16 numberOfCallsBeforeCreation
    ) external {
        vm.assume(contractAdmin != address(0));
        vm.assume(numberOfCallsBeforeCreation < 5);

        address contractCreator = vm.addr(1);

        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.addPermission.selector, 0, contractCreator, 8);

        // we can know ahead of time the expected address
        address expectedContractAddress = factory.deterministicContractAddressWithSetupActions(contractCreator, uri, nameA, contractAdmin, initSetup);

        // create parameters for contract creation
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });

        address[] memory deployments = new address[](2);

        vm.startPrank(contractCreator);
        deployments[0] = factory.getOrCreateContractDeterministic(address(0), uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);
        deployments[1] = factory.getOrCreateContractDeterministic(address(0), uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);
        assertEq(deployments[0], deployments[1]);
    }

    function test_createContractDeterministic_whenContractUpgraded_stillHasSameAddress() external {
        string memory uri = "ipfs://asdfadsf";
        string memory nameA = "nameA";
        address contractAdmin = vm.addr(1);
        // account that creates the contract (not necessarily the owner/admin)
        address contractCreator = vm.addr(2);

        // 1. get the deterministic address of the contract before its created, from the existing factory proxy
        address expectedContractAddress = factory.deterministicContractAddress(contractCreator, uri, nameA, contractAdmin);

        // 2. update the erc1155 implementation:
        // * create a new version of the erc1155 implementation
        // * create a new factory that points to that new erc1155 implementation,
        // * upgrade the proxy to point to the new factory
        IZoraCreator1155 newZoraCreator = new ZoraCreator1155Impl(zora, address(factory), address(new ProtocolRewards()), makeAddr("timedSaleStrategy"));

        ZoraCreator1155FactoryImpl newFactoryImpl = new ZoraCreator1155FactoryImpl(
            newZoraCreator,
            IMinter1155(address(0)),
            IMinter1155(address(0)),
            IMinter1155(address(0))
        );

        vm.prank(zora);
        factory.upgradeTo(address(newFactoryImpl));

        // sanity check - make sure that the proxy erc1155 implementation is pointing to the new implementation
        assertEq(address(factory.zora1155Impl()), address(newZoraCreator));

        // 3. Create a contract with a deterministic address, it should match the address from before the upgrade
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });

        // now create deterministically, address should match expected address
        vm.prank(contractCreator);
        address createdAddress = factory.createContractDeterministic(uri, nameA, royaltyConfig, payable(contractAdmin), new bytes[](0));

        assertEq(createdAddress, expectedContractAddress);
    }

    function test_createContractDeterministic_createdContractCanBeUpgraded() external {
        string memory uri = "ipfs://asdfadsf";
        string memory nameA = "nameA";
        address contractAdmin = vm.addr(1);

        // 1. Have the factory the contract deterministically
        ICreatorRoyaltiesControl.RoyaltyConfiguration memory royaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: 10,
            royaltyRecipient: vm.addr(5),
            royaltyMintSchedule: 0
        });
        bytes[] memory initSetup = new bytes[](1);
        initSetup[0] = abi.encodeWithSelector(IZoraCreator1155.setupNewToken.selector, "ipfs://asdfadsf", 100);

        // now create deterministically, address should match expected address
        address createdAddress = factory.createContractDeterministic(uri, nameA, royaltyConfig, payable(contractAdmin), initSetup);

        ZoraCreator1155Impl creatorProxy = ZoraCreator1155Impl(payable(createdAddress));

        // 2. upgrade the created contract by creating a new contract and upgrading the existing one to point to it.
        IZoraCreator1155 newZoraCreator = new ZoraCreator1155Impl(zora, address(upgradeGate), address(new ProtocolRewards()), makeAddr("timedSaleStrategy"));

        address[] memory baseImpls = new address[](1);
        baseImpls[0] = address(factory.zora1155Impl());

        vm.prank(zora);
        upgradeGate.registerUpgradePath(baseImpls, address(newZoraCreator));

        vm.prank(creatorProxy.owner());
        creatorProxy.upgradeTo(address(newZoraCreator));
    }
}
