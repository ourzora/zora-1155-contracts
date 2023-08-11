// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {ECDSAUpgradeable} from "@zoralabs/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";

import {ZoraCreator1155Impl} from "../../src/nft/ZoraCreator1155Impl.sol";
import {Zora1155} from "../../src/proxies/Zora1155.sol";
import {IZoraCreator1155} from "../../src/interfaces/IZoraCreator1155.sol";
import {ZoraCreator1155Impl} from "../../src/nft/ZoraCreator1155Impl.sol";
import {IMinter1155} from "../../src/interfaces/IMinter1155.sol";
import {ICreatorRoyaltiesControl} from "../../src/interfaces/ICreatorRoyaltiesControl.sol";
import {IZoraCreator1155Factory} from "../../src/interfaces/IZoraCreator1155Factory.sol";
import {ILimitedMintPerAddress} from "../../src/interfaces/ILimitedMintPerAddress.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "../../src/minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {Zora1155Factory} from "../../src/proxies/Zora1155Factory.sol";
import {ZoraCreator1155FactoryImpl} from "../../src/factory/ZoraCreator1155FactoryImpl.sol";
import {ZoraCreator1155PremintExecutor} from "../../src/premint/ZoraCreator1155PremintExecutor.sol";
import {IZoraCreator1155} from "../../src/interfaces/IZoraCreator1155.sol";
import {ZoraCreator1155Attribution, ContractCreationConfig, TokenCreationConfig, PremintConfig} from "../../src/premint/ZoraCreator1155Attribution.sol";

contract ZoraCreator1155PreminterTest is Test {
    ZoraCreator1155PremintExecutor internal preminter;
    ZoraCreator1155FactoryImpl internal factory;
    // setup contract config
    uint256 creatorPrivateKey = 0xA11CE;
    address creator;

    ICreatorRoyaltiesControl.RoyaltyConfiguration defaultRoyaltyConfig;

    event Preminted(
        address indexed contractAddress,
        uint256 indexed tokenId,
        bool indexed createdNewContract,
        uint32 uid,
        ContractCreationConfig contractConfig,
        TokenCreationConfig tokenConfig,
        address minter,
        uint256 quantityMinted
    );

    function setUp() external {
        ProtocolRewards rewards = new ProtocolRewards();
        ZoraCreator1155Impl zoraCreator1155Impl = new ZoraCreator1155Impl(0, makeAddr("zora"), address(0), address(rewards));
        ZoraCreatorFixedPriceSaleStrategy fixedPriceMinter = new ZoraCreatorFixedPriceSaleStrategy();
        factory = new ZoraCreator1155FactoryImpl(zoraCreator1155Impl, IMinter1155(address(1)), fixedPriceMinter, IMinter1155(address(3)));
        uint32 royaltyBPS = 2;
        uint32 royaltyMintSchedule = 20;
        address royaltyRecipient = vm.addr(4);

        defaultRoyaltyConfig = ICreatorRoyaltiesControl.RoyaltyConfiguration({
            royaltyBPS: royaltyBPS,
            royaltyRecipient: royaltyRecipient,
            royaltyMintSchedule: royaltyMintSchedule
        });

        preminter = new ZoraCreator1155PremintExecutor();
        preminter.initialize(factory);

        creatorPrivateKey = 0xA11CE;
        creator = vm.addr(creatorPrivateKey);
    }

    function makeDefaultContractCreationConfig() internal view returns (ContractCreationConfig memory) {
        return ContractCreationConfig({contractAdmin: creator, contractName: "blah", contractURI: "blah.contract"});
    }

    function makeDefaultTokenCreationConfig() internal view returns (TokenCreationConfig memory) {
        IMinter1155 fixedPriceMinter = factory.defaultMinters()[0];
        return
            TokenCreationConfig({
                tokenURI: "blah.token",
                maxSupply: 10,
                maxTokensPerAddress: 5,
                pricePerToken: 0,
                mintStart: 0,
                mintDuration: 0,
                royaltyMintSchedule: defaultRoyaltyConfig.royaltyMintSchedule,
                royaltyBPS: defaultRoyaltyConfig.royaltyBPS,
                royaltyRecipient: defaultRoyaltyConfig.royaltyRecipient,
                fixedPriceMinter: address(fixedPriceMinter)
            });
    }

    function makeDefaultPremintConfig() internal view returns (PremintConfig memory) {
        return
            PremintConfig({
                contractConfig: makeDefaultContractCreationConfig(),
                tokenConfig: makeDefaultTokenCreationConfig(),
                uid: 100,
                version: 0,
                deleted: false
            });
    }

    function test_successfullyMintsTokens() external {
        // 1. Make contract creation params

        // configuration of contract to create
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        string memory comment = "hi";

        // get contract hash, which is unique per contract creation config, and can be used
        // retreive the address created for a contract
        address contractAddress = preminter.getContractAddress(premintConfig.contractConfig);

        // 2. Call smart contract to get digest to sign for creation params.
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, contractAddress, chainId);

        // 3. Sign the digest
        // create a signature with the digest for the params
        bytes memory signature = _sign(creatorPrivateKey, digest);

        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.prank(premintExecutor);
        uint256 tokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);

        // get the contract address from the preminter based on the contract hash id.
        IZoraCreator1155 created1155Contract = IZoraCreator1155(contractAddress);

        // get the created contract, and make sure that tokens have been minted to the address
        assertEq(created1155Contract.balanceOf(premintExecutor, tokenId), quantityToMint);

        // alter the token creation config, create a new signature with the existing
        // contract config and new token config
        premintConfig.tokenConfig.tokenURI = "blah2.token";
        premintConfig.uid++;

        digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, contractAddress, chainId);
        signature = _sign(creatorPrivateKey, digest);

        // premint with new token config and signature
        vm.prank(premintExecutor);
        tokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);

        // a new token shoudl have been created, with x tokens minted to the executor, on the same contract address
        // as before since the contract config didnt change
        assertEq(created1155Contract.balanceOf(premintExecutor, tokenId), quantityToMint);
    }

    function test_signatureForSameContractandUid_cannotBeExecutedTwice() external {
        // 1. Make contract creation params

        // configuration of contract to create
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        _signAndExecutePremint(premintConfig, creatorPrivateKey, chainId, premintExecutor, quantityToMint, comment);

        // create a sig for another token with same uid, it should revert
        premintConfig.tokenConfig.tokenURI = "blah2.token";
        bytes memory signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        vm.startPrank(premintExecutor);
        // premint with new token config and signature - it should revert
        vm.expectRevert(abi.encodeWithSelector(ZoraCreator1155Impl.PremintAlreadyExecuted.selector));
        preminter.premint(premintConfig, signature, quantityToMint, comment);

        // change the version, it should still revert
        premintConfig.version++;
        signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        // premint with new token config and signature - it should revert
        vm.expectRevert(abi.encodeWithSelector(ZoraCreator1155Impl.PremintAlreadyExecuted.selector));
        preminter.premint(premintConfig, signature, quantityToMint, comment);

        // change the uid, it should not revert
        premintConfig.uid++;
        signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        preminter.premint(premintConfig, signature, quantityToMint, comment);
    }

    function test_deleted_preventsTokenFromBeingMinted() external {
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        premintConfig.deleted = true;
        uint chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        uint256 quantityToMint = 2;
        string memory comment = "I love it";

        // 2. Call smart contract to get digest to sign for creation params.
        bytes memory signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.expectRevert(ZoraCreator1155Attribution.PremintDeleted.selector);
        vm.prank(premintExecutor);
        uint256 newTokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);

        assertEq(newTokenId, 0, "tokenId");

        // make sure no contract was created
        assertEq(preminter.getContractAddress(premintConfig.contractConfig).code.length, 0, "contract has been deployed");
    }

    function test_emitsPremint_whenNewContract() external {
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;

        // Sign the premint
        bytes memory signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);

        string memory comment = "I love it";

        vm.startPrank(premintExecutor);

        // we need the contract address to assert the emitted event, so lets premint, get the contract address, rollback, and premint again
        uint256 snapshot = vm.snapshot();
        address contractAddress = preminter.getContractAddress(premintConfig.contractConfig);
        uint256 tokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);
        vm.revertTo(snapshot);

        // now call the premint function, using the same config that was used to generate the digest, and the signature
        bool createdNewContract = true;
        vm.expectEmit(true, true, true, true);
        emit Preminted(
            contractAddress,
            tokenId,
            createdNewContract,
            premintConfig.uid,
            premintConfig.contractConfig,
            premintConfig.tokenConfig,
            premintExecutor,
            quantityToMint
        );
        preminter.premint(premintConfig, signature, quantityToMint, comment);
    }

    function test_onlyOwner_hasAdminRights_onCreatedToken() public {
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        (address createdContractAddress, uint256 newTokenId) = _signAndExecutePremint(
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        // get the contract address from the preminter based on the contract hash id.
        IZoraCreator1155 created1155Contract = IZoraCreator1155(createdContractAddress);

        ZoraCreatorFixedPriceSaleStrategy.SalesConfig memory newSalesConfig = ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
            pricePerToken: 5 ether,
            saleStart: 0,
            saleEnd: 0,
            maxTokensPerAddress: 5,
            fundsRecipient: creator
        });

        IMinter1155 fixedPrice = factory.fixedPriceMinter();

        // have the premint contract try to set the sales config - it should revert with
        // the expected UserMissingRole error
        vm.expectRevert(
            abi.encodeWithSelector(
                IZoraCreator1155.UserMissingRoleForToken.selector,
                address(preminter),
                newTokenId,
                ZoraCreator1155Impl(address(created1155Contract)).PERMISSION_BIT_SALES()
            )
        );
        vm.prank(address(preminter));
        created1155Contract.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(ZoraCreatorFixedPriceSaleStrategy.setSale.selector, newTokenId, newSalesConfig)
        );

        // have admin/creator try to set the sales config - it should succeed
        vm.prank(creator);
        created1155Contract.callSale(
            newTokenId,
            fixedPrice,
            abi.encodeWithSelector(ZoraCreatorFixedPriceSaleStrategy.setSale.selector, newTokenId, newSalesConfig)
        );

        // have the premint contract try to set royalties config - it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IZoraCreator1155.UserMissingRoleForToken.selector,
                address(preminter),
                newTokenId,
                ZoraCreator1155Impl(address(created1155Contract)).PERMISSION_BIT_FUNDS_MANAGER()
            )
        );
        vm.prank(address(preminter));
        created1155Contract.updateRoyaltiesForToken(newTokenId, defaultRoyaltyConfig);

        // have admin/creator try to set royalties config - it should succeed
        vm.prank(creator);
        created1155Contract.updateRoyaltiesForToken(newTokenId, defaultRoyaltyConfig);
    }

    function test_premintStatus_getsStatus() external {
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        uint32 firstUid = premintConfig.uid;
        uint32 secondUid = firstUid + 1;

        ContractCreationConfig memory firstContractConfig = premintConfig.contractConfig;
        ContractCreationConfig memory secondContractConfig = ContractCreationConfig(
            firstContractConfig.contractAdmin,
            firstContractConfig.contractURI,
            string.concat(firstContractConfig.contractName, "4")
        );

        (address firstResultContractAddress, uint256 firstResultTokenId) = _signAndExecutePremint(
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertEq(IZoraCreator1155(firstResultContractAddress).balanceOf(premintExecutor, firstResultTokenId), quantityToMint);

        premintConfig.uid = secondUid;
        (address secondResultContractAddress, uint256 secondResultTokenId) = _signAndExecutePremint(
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertEq(firstResultContractAddress, secondResultContractAddress);
        assertEq(IZoraCreator1155(firstResultContractAddress).balanceOf(premintExecutor, secondResultTokenId), quantityToMint);

        premintConfig.contractConfig = secondContractConfig;
        (address thirdResultContractAddress, uint256 thirdResultTokenId) = _signAndExecutePremint(
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertFalse(firstResultContractAddress == thirdResultContractAddress);
        assertEq(IZoraCreator1155(thirdResultContractAddress).balanceOf(premintExecutor, thirdResultTokenId), quantityToMint);
    }

    function test_premintCanOnlyBeExecutedAfterStartDate(uint8 startDate, uint8 currentTime) external {
        bool shouldRevert;
        if (startDate == 0) {
            shouldRevert = false;
        } else {
            // should revert if before the start date
            shouldRevert = currentTime < startDate;
        }
        vm.warp(currentTime);

        PremintConfig memory premintConfig = makeDefaultPremintConfig();
        premintConfig.tokenConfig.mintStart = startDate;

        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        // get signature for the premint:
        bytes memory signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        if (shouldRevert) {
            vm.expectRevert(ZoraCreator1155Attribution.MintNotYetStarted.selector);
        }
        vm.prank(premintExecutor);
        preminter.premint(premintConfig, signature, quantityToMint, comment);
    }

    function test_premintCanOnlyBeExecutedUpToDurationFromFirstMint(uint8 startDate, uint8 duration, uint8 timeOfFirstMint, uint8 timeOfSecondMint) external {
        vm.assume(timeOfFirstMint >= startDate);
        vm.assume(timeOfSecondMint >= timeOfFirstMint);

        bool shouldRevert;
        if (duration == 0) {
            shouldRevert = false;
        } else {
            // should revert if after the duration
            shouldRevert = uint16(timeOfSecondMint) > uint16(timeOfFirstMint) + duration;
        }

        // build a premint with a token that has the given start date and duration
        PremintConfig memory premintConfig = makeDefaultPremintConfig();
        premintConfig.tokenConfig.mintStart = startDate;
        premintConfig.tokenConfig.mintDuration = duration;

        uint256 chainId = block.chainid;

        // get signature for the premint:
        bytes memory signature = _signPremint(premintConfig, creatorPrivateKey, chainId);

        uint256 quantityToMint = 2;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        vm.startPrank(premintExecutor);

        vm.warp(timeOfFirstMint);
        uint256 tokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);

        vm.warp(timeOfSecondMint);

        address contractAddress = preminter.getContractAddress(premintConfig.contractConfig);
        // execute mint directly on the contract - and check make sure it reverts if minted after sale start
        IMinter1155 fixedPriceMinter = factory.defaultMinters()[0];
        if (shouldRevert) {
            vm.expectRevert(ZoraCreatorFixedPriceSaleStrategy.SaleEnded.selector);
        }

        IZoraCreator1155(contractAddress).mint(fixedPriceMinter, tokenId, quantityToMint, abi.encode(premintExecutor, comment));
    }

    function _signAndExecutePremint(
        PremintConfig memory premintConfig,
        uint256 privateKey,
        uint256 chainId,
        address executor,
        uint256 quantityToMint,
        string memory comment
    ) private returns (address contractAddress, uint256 newTokenId) {
        bytes memory signature = _signPremint(premintConfig, privateKey, chainId);

        // now call the premint function, using the same config that was used to generate the digest, and the signature
        contractAddress = preminter.getContractAddress(premintConfig.contractConfig);
        vm.prank(executor);
        newTokenId = preminter.premint(premintConfig, signature, quantityToMint, comment);
    }

    function _signPremint(PremintConfig memory premintConfig, uint256 privateKey, uint256 chainId) private view returns (bytes memory) {
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, preminter.getContractAddress(premintConfig.contractConfig), chainId);

        // 3. Sign the digest
        // create a signature with the digest for the params
        return _sign(privateKey, digest);
    }

    function _sign(uint256 privateKey, bytes32 digest) private pure returns (bytes memory) {
        // sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // combine into a single bytes array
        return abi.encodePacked(r, s, v);
    }
}
