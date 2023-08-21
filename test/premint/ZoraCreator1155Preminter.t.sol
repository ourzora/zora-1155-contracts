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
import {ForkDeploymentConfig} from "../../src/deployment/DeploymentConfig.sol";

contract ZoraCreator1155PreminterTest is ForkDeploymentConfig, Test {
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

        preminter = new ZoraCreator1155PremintExecutor(factory);

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
        return PremintConfig({tokenConfig: makeDefaultTokenCreationConfig(), uid: 100, version: 0, deleted: false});
    }

    function test_successfullyMintsTokens() external {
        // 1. Make contract creation params

        // configuration of contract to create
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        string memory comment = "hi";

        // get contract hash, which is unique per contract creation config, and can be used
        // retreive the address created for a contract
        address contractAddress = preminter.getContractAddress(contractConfig);

        // 2. Call smart contract to get digest to sign for creation params.
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, contractAddress, chainId);

        // 3. Sign the digest
        // create a signature with the digest for the params
        bytes memory signature = _sign(creatorPrivateKey, digest);

        uint256 mintFee = 0;

        uint256 mintCost = mintFee * quantityToMint;

        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        vm.deal(premintExecutor, mintCost);
        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.prank(premintExecutor);
        uint256 tokenId = preminter.premint{value: mintCost}(contractConfig, premintConfig, signature, quantityToMint, comment);

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
        tokenId = preminter.premint{value: mintCost}(contractConfig, premintConfig, signature, quantityToMint, comment);

        // a new token shoudl have been created, with x tokens minted to the executor, on the same contract address
        // as before since the contract config didnt change
        assertEq(created1155Contract.balanceOf(premintExecutor, tokenId), quantityToMint);
    }

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

    function testTheForkPremint(string memory chainName) private {
        console.log("testing on fork: ", chainName);

        // create and select the fork, which will be used for all subsequent calls
        // it will also affect the current block chain id based on the rpc url returned
        vm.createSelectFork(vm.rpcUrl(chainName));

        // get contract hash, which is unique per contract creation config, and can be used
        // retreive the address created for a contract
        preminter = ZoraCreator1155PremintExecutor(getDeployment().preminter);
        factory = ZoraCreator1155FactoryImpl(getDeployment().factoryImpl);

        console.log("building defaults");

        // configuration of contract to create
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        string memory comment = "hi";

        console.log("loading preminter");

        address contractAddress = preminter.getContractAddress(contractConfig);

        console.log(contractAddress);

        // 2. Call smart contract to get digest to sign for creation params.
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, contractAddress, chainId);

        // 3. Sign the digest
        // create a signature with the digest for the params
        bytes memory signature = _sign(creatorPrivateKey, digest);

        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        uint256 mintCost = quantityToMint * 0.000777 ether;
        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.deal(premintExecutor, mintCost);
        vm.prank(premintExecutor);
        uint256 tokenId = preminter.premint{value: mintCost}(contractConfig, premintConfig, signature, quantityToMint, comment);

        // get the contract address from the preminter based on the contract hash id.
        IZoraCreator1155 created1155Contract = IZoraCreator1155(contractAddress);

        // get the created contract, and make sure that tokens have been minted to the address
        assertEq(created1155Contract.balanceOf(premintExecutor, tokenId), quantityToMint);
    }

    function test_fork_successfullyMintsTokens() external {
        string[] memory forkTestChains = getForkTestChains();
        for (uint256 i = 0; i < forkTestChains.length; i++) {
            testTheForkPremint(forkTestChains[i]);
        }
    }

    function test_signatureForSameContractandUid_cannotBeExecutedTwice() external {
        // 1. Make contract creation params

        // configuration of contract to create
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        address contractAddress = preminter.getContractAddress(contractConfig);
        _signAndExecutePremint(contractConfig, premintConfig, creatorPrivateKey, chainId, premintExecutor, quantityToMint, comment);

        // create a sig for another token with same uid, it should revert
        premintConfig.tokenConfig.tokenURI = "blah2.token";
        bytes memory signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        vm.startPrank(premintExecutor);
        // premint with new token config and signature - it should revert
        vm.expectRevert(abi.encodeWithSelector(ZoraCreator1155Impl.PremintAlreadyExecuted.selector));
        preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);

        // change the version, it should still revert
        premintConfig.version++;
        signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        // premint with new token config and signature - it should revert
        vm.expectRevert(abi.encodeWithSelector(ZoraCreator1155Impl.PremintAlreadyExecuted.selector));
        preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);

        // change the uid, it should not revert
        premintConfig.uid++;
        signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);
    }

    function test_deleted_preventsTokenFromBeingMinted() external {
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        premintConfig.deleted = true;
        uint chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        uint256 quantityToMint = 2;
        string memory comment = "I love it";

        address contractAddress = preminter.getContractAddress(contractConfig);

        // 2. Call smart contract to get digest to sign for creation params.
        bytes memory signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.expectRevert(ZoraCreator1155Attribution.PremintDeleted.selector);
        vm.prank(premintExecutor);
        uint256 newTokenId = preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);

        assertEq(newTokenId, 0, "tokenId");

        // make sure no contract was created
        assertEq(contractAddress.code.length, 0, "contract has been deployed");
    }

    function test_emitsPremint_whenNewContract() external {
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();
        address contractAddress = preminter.getContractAddress(contractConfig);

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;

        // Sign the premint
        bytes memory signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        uint256 expectedTokenId = 1;

        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);

        string memory comment = "I love it";

        vm.startPrank(premintExecutor);

        bool createdNewContract = true;
        vm.expectEmit(true, true, true, true);
        emit Preminted(
            contractAddress,
            expectedTokenId,
            createdNewContract,
            premintConfig.uid,
            contractConfig,
            premintConfig.tokenConfig,
            premintExecutor,
            quantityToMint
        );
        preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);
    }

    function test_onlyOwner_hasAdminRights_onCreatedToken() public {
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // how many tokens are minted to the executor
        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        // this account will be used to execute the premint, and should result in a contract being created
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        address createdContractAddress = preminter.getContractAddress(contractConfig);

        uint256 newTokenId = _signAndExecutePremint(contractConfig, premintConfig, creatorPrivateKey, chainId, premintExecutor, quantityToMint, comment);

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

        ContractCreationConfig memory firstContractConfig = makeDefaultContractCreationConfig();
        ContractCreationConfig memory secondContractConfig = ContractCreationConfig(
            firstContractConfig.contractAdmin,
            firstContractConfig.contractURI,
            string.concat(firstContractConfig.contractName, "4")
        );

        address firstContractAddress = preminter.getContractAddress(firstContractConfig);
        uint256 firstResultTokenId = _signAndExecutePremint(
            firstContractConfig,
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertEq(IZoraCreator1155(firstContractAddress).balanceOf(premintExecutor, firstResultTokenId), quantityToMint);

        premintConfig.uid = secondUid;
        uint256 secondResultTokenId = _signAndExecutePremint(
            firstContractConfig,
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertEq(IZoraCreator1155(firstContractAddress).balanceOf(premintExecutor, secondResultTokenId), quantityToMint);

        address secondContractAddress = preminter.getContractAddress(secondContractConfig);
        uint256 thirdResultTokenId = _signAndExecutePremint(
            secondContractConfig,
            premintConfig,
            creatorPrivateKey,
            chainId,
            premintExecutor,
            quantityToMint,
            comment
        );

        assertEq(IZoraCreator1155(secondContractAddress).balanceOf(premintExecutor, thirdResultTokenId), quantityToMint);
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

        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();
        premintConfig.tokenConfig.mintStart = startDate;

        uint256 quantityToMint = 4;
        uint256 chainId = block.chainid;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        // get signature for the premint:
        bytes memory signature = _signPremint(preminter.getContractAddress(contractConfig), premintConfig, creatorPrivateKey, chainId);

        if (shouldRevert) {
            vm.expectRevert(ZoraCreator1155Attribution.MintNotYetStarted.selector);
        }
        vm.prank(premintExecutor);
        preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);
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
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();
        address contractAddress = preminter.getContractAddress(contractConfig);

        premintConfig.tokenConfig.mintStart = startDate;
        premintConfig.tokenConfig.mintDuration = duration;

        uint256 chainId = block.chainid;

        // get signature for the premint:
        bytes memory signature = _signPremint(contractAddress, premintConfig, creatorPrivateKey, chainId);

        uint256 quantityToMint = 2;
        address premintExecutor = vm.addr(701);
        string memory comment = "I love it";

        vm.startPrank(premintExecutor);

        vm.warp(timeOfFirstMint);
        uint256 tokenId = preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);

        vm.warp(timeOfSecondMint);

        // execute mint directly on the contract - and check make sure it reverts if minted after sale start
        IMinter1155 fixedPriceMinter = factory.defaultMinters()[0];
        if (shouldRevert) {
            vm.expectRevert(ZoraCreatorFixedPriceSaleStrategy.SaleEnded.selector);
        }

        IZoraCreator1155(contractAddress).mint(fixedPriceMinter, tokenId, quantityToMint, abi.encode(premintExecutor, comment));
    }

    function test_premintStatus_getsIfContractHasBeenCreatedAndTokenIdForPremint() external {
        // build a premint
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        // get premint status
        (bool contractCreated, uint256 tokenId) = preminter.premintStatus(preminter.getContractAddress(contractConfig), premintConfig.uid);
        // contract should not be created and token id should be 0
        assertEq(contractCreated, false);
        assertEq(tokenId, 0);

        // sign and execute premint
        uint256 newTokenId = _signAndExecutePremint(contractConfig, premintConfig, creatorPrivateKey, block.chainid, vm.addr(701), 1, "hi");

        // get status
        (contractCreated, tokenId) = preminter.premintStatus(preminter.getContractAddress(contractConfig), premintConfig.uid);
        // contract should be created and token id should be same as one that was created
        assertEq(contractCreated, true);
        assertEq(tokenId, newTokenId);

        // get status for another uid
        (contractCreated, tokenId) = preminter.premintStatus(preminter.getContractAddress(contractConfig), premintConfig.uid + 1);
        // contract should be created and token id should be 0
        assertEq(contractCreated, true);
        assertEq(tokenId, 0);
    }

    // todo: pull from elsewhere
    uint256 constant CONTRACT_BASE_ID = 0;
    uint256 constant PERMISSION_BIT_MINTER = 2 ** 2;

    function test_premint_whenContractCreated_premintCanOnlyBeExecutedByPermissionBitMinter() external {
        // build a premint
        ContractCreationConfig memory contractConfig = makeDefaultContractCreationConfig();
        PremintConfig memory premintConfig = makeDefaultPremintConfig();

        address executor = vm.addr(701);

        // sign and execute premint
        bytes memory signature = _signPremint(preminter.getContractAddress(contractConfig), premintConfig, creatorPrivateKey, block.chainid);

        (bool isValidSignature, address contractAddress, ) = preminter.isValidSignature(contractConfig, premintConfig, signature);

        assertTrue(isValidSignature);

        _signAndExecutePremint(contractConfig, premintConfig, creatorPrivateKey, block.chainid, executor, 1, "hi");

        // contract has been created

        // have another creator sign a premint
        uint256 newCreatorPrivateKey = 0xA11CF;
        address newCreator = vm.addr(newCreatorPrivateKey);
        PremintConfig memory premintConfig2 = premintConfig;
        premintConfig2.uid++;

        // have new creator sign a premint, isValidSignature should be false, and premint should revert
        bytes memory newCreatorSignature = _signPremint(contractAddress, premintConfig2, newCreatorPrivateKey, block.chainid);

        // it should not be considered a valid signature
        (isValidSignature, , ) = preminter.isValidSignature(contractConfig, premintConfig2, newCreatorSignature);

        assertFalse(isValidSignature);

        // try to mint, it should revert
        vm.expectRevert(abi.encodeWithSelector(IZoraCreator1155.UserMissingRoleForToken.selector, newCreator, CONTRACT_BASE_ID, PERMISSION_BIT_MINTER));
        vm.prank(executor);
        preminter.premint(contractConfig, premintConfig2, newCreatorSignature, 1, "yo");

        // now grant the new creator permission to mint
        vm.prank(creator);
        IZoraCreator1155(contractAddress).addPermission(CONTRACT_BASE_ID, newCreator, PERMISSION_BIT_MINTER);

        // should now be considered a valid signature
        (isValidSignature, , ) = preminter.isValidSignature(contractConfig, premintConfig2, newCreatorSignature);
        assertTrue(isValidSignature);

        // try to mint again, should not revert
        vm.prank(executor);
        preminter.premint(contractConfig, premintConfig2, newCreatorSignature, 1, "yo");
    }

    function _signAndExecutePremint(
        ContractCreationConfig memory contractConfig,
        PremintConfig memory premintConfig,
        uint256 privateKey,
        uint256 chainId,
        address executor,
        uint256 quantityToMint,
        string memory comment
    ) private returns (uint256 newTokenId) {
        bytes memory signature = _signPremint(preminter.getContractAddress(contractConfig), premintConfig, privateKey, chainId);

        // now call the premint function, using the same config that was used to generate the digest, and the signature
        vm.prank(executor);
        newTokenId = preminter.premint(contractConfig, premintConfig, signature, quantityToMint, comment);
    }

    function _signPremint(
        address contractAddress,
        PremintConfig memory premintConfig,
        uint256 privateKey,
        uint256 chainId
    ) private pure returns (bytes memory) {
        bytes32 digest = ZoraCreator1155Attribution.premintHashedTypeDataV4(premintConfig, contractAddress, chainId);

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
