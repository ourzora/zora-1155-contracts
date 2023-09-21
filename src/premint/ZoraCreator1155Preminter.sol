// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ICreatorRoyaltiesControl} from "../interfaces/ICreatorRoyaltiesControl.sol";
import {EIP712UpgradeableWithChainId} from "./EIP712UpgradeableWithChainId.sol";
import {ECDSAUpgradeable} from "@zoralabs/openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@zoralabs/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@zoralabs/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {IZoraCreator1155} from "../interfaces/IZoraCreator1155.sol";
import {IZoraCreator1155Factory} from "../interfaces/IZoraCreator1155Factory.sol";
import {SharedBaseConstants} from "../shared/SharedBaseConstants.sol";
import {ZoraCreatorFixedPriceSaleStrategy} from "../minters/fixed-price/ZoraCreatorFixedPriceSaleStrategy.sol";
import {IMinter1155} from "../interfaces/IMinter1155.sol";

/// @title Enables a creator to signal intent to create a Zora erc1155 contract or new token on that
/// contract by signing a transaction but not paying gas, and have a third party/collector pay the gas
/// by executing the transaction.  Incentivizes the third party to execute the transaction by offering
/// a reward in the form of minted tokens.
/// @author @oveddan
contract ZoraCreator1155Preminter is EIP712UpgradeableWithChainId, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    IZoraCreator1155Factory factory;
    IMinter1155 fixedPriceMinter;

    /// @notice copied from SharedBaseConstants
    uint256 constant CONTRACT_BASE_ID = 0;
    /// @notice This user role allows for any action to be performed
    /// @dev copied from ZoraCreator1155Impl
    uint256 constant PERMISSION_BIT_ADMIN = 2 ** 1;
    /// @notice This user role allows for only mint actions to be performed.
    /// @dev copied from ZoraCreator1155Impl
    uint256 constant PERMISSION_BIT_MINTER = 2 ** 2;
    uint256 constant PERMISSION_BIT_SALES = 2 ** 3;

    /// @dev The resulting token id created for a permint.
    /// determinstic contract address => token id => created token id
    /// if token not created yet, result id will be 0
    mapping(address => mapping(uint32 => uint256)) public premintTokenId;

    error PremintAlreadyExecuted();
    error MintNotYetStarted();
    error InvalidSignature();

    function initialize(IZoraCreator1155Factory _factory) public initializer {
        __EIP712_init("Preminter", "0.0.1");
        factory = _factory;
        fixedPriceMinter = _factory.defaultMinters()[0];
    }

    struct ContractCreationConfig {
        // Creator/admin of the created contract.  Must match the account that signed the message
        address contractAdmin;
        // Metadata URI for the created contract
        string contractURI;
        // Name of the created contract
        string contractName;
    }

    struct TokenCreationConfig {
        // Metadata URI for the created token
        string tokenURI;
        // Max supply of the created token
        uint256 maxSupply;
        // Max tokens that can be minted for an address, 0 if unlimited
        uint64 maxTokensPerAddress;
        // Price per token in eth wei. 0 for a free mint.
        uint96 pricePerToken;
        // The start time of the mint, 0 for immediate.  Prevents signatures from being used until the start time.
        uint64 mintStart;
        // The duration of the mint, starting from the first mint of this token. 0 for infinite
        uint64 mintDuration;
        // RoyaltyMintSchedule for created tokens. Every nth token will go to the royalty recipient.
        uint32 royaltyMintSchedule;
        // RoyaltyBPS for created tokens. The royalty amount in basis points for secondary sales.
        uint32 royaltyBPS;
        // RoyaltyRecipient for created tokens. The address that will receive the royalty payments.
        address royaltyRecipient;
    }

    struct PremintConfig {
        // The config for the contract to be created
        ContractCreationConfig contractConfig;
        // The config for the token to be created
        TokenCreationConfig tokenConfig;
        // Unique id of the token, used to ensure that multiple signatures can't be used to create the same intended token.
        // only one signature per token id, scoped to the contract hash can be executed.
        uint32 uid;
        // Version of this premint, scoped to the uid and contract.  Not used for logic in the contract, but used externally to track the newest version
        uint32 version;
        // If executing this signature results in preventing any signature with this uid from being minted.
        bool deleted;
    }

    struct PremintStatus {
        // If the signature has been executed
        bool executed;
        // If premint has been executed, the contract address
        address contractAddress;
        // If premint has been executed, the created token id
        uint256 tokenId;
    }

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

    // same signature should work whether or not there is an existing contract
    // so it is unaware of order, it just takes the token uri and creates the next token with it
    // this could include creating the contract.
    function premint(
        PremintConfig calldata premintConfig,
        /// @notice Unique id of the token, used to ensure that multiple signatures can't be used to create the same intended token, in the case
        /// that a signature is updated for a token, and the old signature is executed, two tokens for the same original intended token could be created.
        /// Only one signature per token id, scoped to the contract hash can be executed.
        bytes calldata signature,
        uint256 quantityToMint,
        string calldata mintComment
    ) public payable nonReentrant returns (address contractAddress, uint256 newTokenId) {
        // 1. Validate the signature.
        // 2. Create an erc1155 contract with the given name and uri and the creator as the admin/owner
        // 3. Allow this contract to create new new tokens on the contract
        // 4. Mint a new token, and get the new token id
        // 5. Setup fixed price minting rules for the new token
        // 6. Make the creator an admin of that token (and remove this contracts admin rights)
        // 7. Mint x tokens, as configured, to the executor of this transaction.

        _validateSignature(premintConfig, signature);

        if (premintConfig.tokenConfig.mintStart != 0 && premintConfig.tokenConfig.mintStart > block.timestamp) {
            // if the mint start is in the future, then revert
            revert MintNotYetStarted();
        }

        if (premintConfig.deleted) {
            // if the signature says to be deleted, then dont execute any further minting logic
            return (address(0), 0);
        }

        ContractCreationConfig calldata contractConfig = premintConfig.contractConfig;
        TokenCreationConfig calldata tokenConfig = premintConfig.tokenConfig;

        // get or create the contract with the given params
        (IZoraCreator1155 tokenContract, bool isNewContract) = _getOrCreateContract(contractConfig);
        contractAddress = address(tokenContract);

        // make sure a token hasn't been minted for the premint token uid and contract address
        if (premintTokenId[contractAddress][premintConfig.uid] != 0) {
            revert PremintAlreadyExecuted();
        }

        // setup the new token, and its sales config
        newTokenId = _setupNewTokenAndSale(tokenContract, contractConfig.contractAdmin, tokenConfig);

        premintTokenId[contractAddress][premintConfig.uid] = newTokenId;

        emit Preminted(contractAddress, newTokenId, isNewContract, premintConfig.uid, contractConfig, tokenConfig, msg.sender, quantityToMint);

        // mint the initial x tokens for this new token id to the executor.
        address tokenRecipient = msg.sender;
        tokenContract.mint{value: msg.value}(fixedPriceMinter, newTokenId, quantityToMint, abi.encode(tokenRecipient, mintComment));
    }

    function _getOrCreateContract(ContractCreationConfig calldata contractConfig) private returns (IZoraCreator1155 tokenContract, bool isNewContract) {
        address contractAddress = getContractAddress(contractConfig);
        // first we see if the code is already deployed for the contract
        isNewContract = contractAddress.code.length == 0;

        if (isNewContract) {
            // if address doesnt exist for hash, createi t
            tokenContract = _createContract(contractConfig);
        } else {
            tokenContract = IZoraCreator1155(contractAddress);
        }
    }

    function _createContract(ContractCreationConfig calldata contractConfig) private returns (IZoraCreator1155 tokenContract) {
        // we need to build the setup actions, that must:
        // grant this contract ability to mint tokens - when a token is minted, this contract is
        // granted admin rights on that token
        bytes[] memory setupActions = new bytes[](1);
        setupActions[0] = abi.encodeWithSelector(IZoraCreator1155.addPermission.selector, CONTRACT_BASE_ID, address(this), PERMISSION_BIT_MINTER);

        // create the contract via the factory.
        address newContractAddresss = factory.createContractDeterministic(
            contractConfig.contractURI,
            contractConfig.contractName,
            // default royalty config is empty, since we set it on a token level
            ICreatorRoyaltiesControl.RoyaltyConfiguration({royaltyBPS: 0, royaltyRecipient: address(0), royaltyMintSchedule: 0}),
            payable(contractConfig.contractAdmin),
            setupActions
        );
        tokenContract = IZoraCreator1155(newContractAddresss);
    }

    function _setupNewTokenAndSale(
        IZoraCreator1155 tokenContract,
        address contractAdmin,
        TokenCreationConfig calldata tokenConfig
    ) private returns (uint256 newTokenId) {
        // mint a new token, and get its token id
        // this contract has admin rights on that token

        newTokenId = tokenContract.setupNewToken(tokenConfig.tokenURI, tokenConfig.maxSupply);

        // set up the sales strategy
        // first, grant the fixed price sale strategy minting capabilities on the token
        tokenContract.addPermission(newTokenId, address(fixedPriceMinter), PERMISSION_BIT_MINTER);

        // set the sales config on that token
        tokenContract.callSale(
            newTokenId,
            fixedPriceMinter,
            abi.encodeWithSelector(
                ZoraCreatorFixedPriceSaleStrategy.setSale.selector,
                newTokenId,
                _buildNewSalesConfig(contractAdmin, tokenConfig.pricePerToken, tokenConfig.maxTokensPerAddress, tokenConfig.mintDuration)
            )
        );

        // set the royalty config on that token:
        tokenContract.updateRoyaltiesForToken(
            newTokenId,
            ICreatorRoyaltiesControl.RoyaltyConfiguration({
                royaltyBPS: tokenConfig.royaltyBPS,
                royaltyRecipient: tokenConfig.royaltyRecipient,
                royaltyMintSchedule: tokenConfig.royaltyMintSchedule
            })
        );

        // remove this contract as admin of the newly created token:
        tokenContract.removePermission(newTokenId, address(this), PERMISSION_BIT_ADMIN);
    }

    function recoverSigner(PremintConfig calldata premintConfig, bytes calldata signature) public view returns (address signatory) {
        // first validate the signature - the creator must match the signer of the message
        bytes32 digest = premintHashData(
            premintConfig,
            // here we pass the current contract and chain id, ensuring that the message
            // only works for the current chain and contract id
            address(this),
            block.chainid
        );

        signatory = ECDSAUpgradeable.recover(digest, signature);
    }

    /// Gets hash data to sign for a premint.  Allows specifying a different chain id and contract address so that the signature
    /// can be verified on a different chain.
    /// @param premintConfig Premint config to hash
    /// @param verifyingContract Contract address that signature is to be verified against
    /// @param chainId Chain id that signature is to be verified on
    function premintHashData(PremintConfig calldata premintConfig, address verifyingContract, uint256 chainId) public view returns (bytes32) {
        bytes32 encoded = _hashPremintConfig(premintConfig);

        // build the struct hash to be signed
        // here we pass the chain id, allowing the message to be signed for another chain
        return _hashTypedDataV4(encoded, verifyingContract, chainId);
    }

    bytes32 constant CONTRACT_AND_TOKEN_DOMAIN =
        keccak256(
            "Premint(ContractCreationConfig contractConfig,TokenCreationConfig tokenConfig,uint32 uid,uint32 version,bool deleted)ContractCreationConfig(address contractAdmin,string contractURI,string contractName)TokenCreationConfig(string tokenURI,uint256 maxSupply,uint64 maxTokensPerAddress,uint96 pricePerToken,uint64 mintStart,uint64 mintDuration,uint32 royaltyMintSchedule,uint32 royaltyBPS,address royaltyRecipient)"
        );

    function _hashPremintConfig(PremintConfig calldata premintConfig) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CONTRACT_AND_TOKEN_DOMAIN,
                    _hashContract(premintConfig.contractConfig),
                    _hashToken(premintConfig.tokenConfig),
                    premintConfig.uid,
                    premintConfig.version,
                    premintConfig.deleted
                )
            );
    }

    bytes32 constant TOKEN_DOMAIN =
        keccak256(
            "TokenCreationConfig(string tokenURI,uint256 maxSupply,uint64 maxTokensPerAddress,uint96 pricePerToken,uint64 mintStart,uint64 mintDuration,uint32 royaltyMintSchedule,uint32 royaltyBPS,address royaltyRecipient)"
        );

    function _hashToken(TokenCreationConfig calldata tokenConfig) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    TOKEN_DOMAIN,
                    _stringHash(tokenConfig.tokenURI),
                    tokenConfig.maxSupply,
                    tokenConfig.maxTokensPerAddress,
                    tokenConfig.pricePerToken,
                    tokenConfig.mintStart,
                    tokenConfig.mintDuration,
                    tokenConfig.royaltyMintSchedule,
                    tokenConfig.royaltyBPS,
                    tokenConfig.royaltyRecipient
                )
            );
    }

    bytes32 constant CONTRACT_DOMAIN = keccak256("ContractCreationConfig(address contractAdmin,string contractURI,string contractName)");

    function _hashContract(ContractCreationConfig calldata contractConfig) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(CONTRACT_DOMAIN, contractConfig.contractAdmin, _stringHash(contractConfig.contractURI), _stringHash(contractConfig.contractName))
            );
    }

    function getPremintedTokenId(ContractCreationConfig calldata contractConfig, uint32 tokenUid) public view returns (uint256) {
        address contractAddress = getContractAddress(contractConfig);

        return premintTokenId[contractAddress][tokenUid];
    }

    function premintHasBeenExecuted(ContractCreationConfig calldata contractConfig, uint32 tokenUid) public view returns (bool) {
        return getPremintedTokenId(contractConfig, tokenUid) != 0;
    }

    /// Validates that the signer of the signature matches the contract admin
    /// Checks if the signature is used; if it is, reverts.
    /// If it isn't mark that it has been used.
    function _validateSignature(PremintConfig calldata premintConfig, bytes calldata signature) private view {
        // first validate the signature - the creator must match the signer of the message
        // contractAddress = getContractAddress(premintConfig.contractConfig);
        address signatory = recoverSigner(premintConfig, signature);

        if (signatory != premintConfig.contractConfig.contractAdmin) {
            revert InvalidSignature();
        }
    }

    function getContractAddress(ContractCreationConfig calldata contractConfig) public view returns (address) {
        return factory.deterministicContractAddress(address(this), contractConfig.contractURI, contractConfig.contractName, contractConfig.contractAdmin);
    }

    function _stringHash(string calldata value) private pure returns (bytes32) {
        return keccak256(bytes(value));
    }

    function _buildNewSalesConfig(
        address creator,
        uint96 pricePerToken,
        uint64 maxTokensPerAddress,
        uint64 duration
    ) private view returns (ZoraCreatorFixedPriceSaleStrategy.SalesConfig memory) {
        uint64 saleStart = uint64(block.timestamp);
        uint64 saleEnd = duration == 0 ? type(uint64).max : saleStart + duration;

        return
            ZoraCreatorFixedPriceSaleStrategy.SalesConfig({
                pricePerToken: pricePerToken,
                saleStart: saleStart,
                saleEnd: saleEnd,
                maxTokensPerAddress: maxTokensPerAddress,
                fundsRecipient: creator
            });
    }
}
