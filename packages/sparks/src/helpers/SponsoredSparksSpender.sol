// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IZoraSparks1155} from "../interfaces/IZoraSparks1155.sol";
import {IZoraSparks1155Managed} from "../interfaces/IZoraSparks1155Managed.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Redemption} from "../ZoraSparksTypes.sol";
import {IUnwrapAndForwardAction} from "../interfaces/IUnwrapAndForwardAction.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVersionedNamedContract} from "@zoralabs/shared-contracts/interfaces/IVersionedNamedContract.sol";
import {ISponsoredSparksSpender, SponsoredMintBatch, SponsoredSpend} from "../interfaces/ISponsoredSparksSpender.sol";

/// @notice Calling interface for the 1155 transfer action to this contract
interface ISponsoredSparksSpenderAction {
    function sponsoredMintBatch(SponsoredMintBatch memory sponsoredMintBatch, bytes memory signature) external;
}

abstract contract ERC1155TransferRecipientConstants {
    bytes4 constant ON_ERC1155_BATCH_RECEIVED_HASH = IERC1155Receiver.onERC1155BatchReceived.selector;
    bytes4 constant ON_ERC1155_RECEIVED_HASH = IERC1155Receiver.onERC1155Received.selector;
}

/// @title Gas tank to fund add'tl relay and mint fess
/// @author iainnash
contract SponsoredSparksSpender is EIP712, ERC1155TransferRecipientConstants, ISponsoredSparksSpender, IVersionedNamedContract, Ownable2Step {
    /// @notice Sparks contract to check that incoming NFTs are from the right contract
    IZoraSparks1155 private immutable zoraSparks1155;

    /// @notice Expected to be set to 0 – used to determine the received unwrapped ETH amount
    uint256 private transientReceivedAmount;

    /// @notice NAME for SponsoredMintHash signature
    string public constant NAME = "SponsoredSparksSpender";
    /// @notice VERSION for SponsoredMintHash signature
    string public constant VERSION = "1";

    /// @notice Typehash for Sponsorship event
    bytes32 public constant SPONSORSHIP_TYPEHASH =
        keccak256(
            "SponsoredMintBatch(address verifier,address from,address destination,bytes data,uint256 expectedRedeemAmount,uint256 totalAmount,uint256[] ids,uint256[] quantities,uint256 nonce,uint256 deadline)"
        );

    /// @notice Typehash for generic Sponsored Spend
    bytes32 public constant SPONSORED_SPEND_TYPEHASH =
        keccak256(
            "SponsoredSpend(address verifier,address from,address destination,bytes data,uint256 expectedInputAmount,uint256 totalAmount,uint256 nonce,uint256 deadline)"
        );

    /// @notice Used nonces from signatures
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    /// @notice Allowed verifiers for spending signatures
    mapping(address => bool) public allowedVerifiers;

    /// @param _zoraSparks1155 Zora Sparks address, can be set to 0x0 for chains that do not have sparks
    /// @param fundsManager Admin for this contract
    /// @param defaultVerifiers Default verifier addresses
    constructor(IZoraSparks1155 _zoraSparks1155, address fundsManager, address[] memory defaultVerifiers) EIP712(NAME, VERSION) Ownable(fundsManager) {
        zoraSparks1155 = _zoraSparks1155;

        for (uint256 i; i < defaultVerifiers.length; i++) {
            if (defaultVerifiers[i] != address(0)) {
                _setVerifierStatus(defaultVerifiers[i], true);
            }
        }
    }

    /** Modifiers */

    modifier resetTransientEthReceived() {
        transientReceivedAmount = 0;
        _;
        transientReceivedAmount = 0;
    }

    /// @dev Only the pool manager may call this function
    modifier onlySparks() {
        if (msg.sender != address(zoraSparks1155)) {
            revert NotZoraSparks1155();
        }

        _;
    }

    /** Metadata */

    /// @notice Informational contract name getter
    function contractName() external pure returns (string memory) {
        return NAME;
    }

    /// @notice Informational version getter
    function contractVersion() external pure returns (string memory) {
        return "2.0.0";
    }

    /** Admin Functions */
    /// @notice Set enabled/disabled verifier wallets
    /// @dev Can be used to rotate hot wallets associated with this contract
    function setVerifierStatus(address verifier, bool enabled) external onlyOwner {
        _setVerifierStatus(verifier, enabled);
    }

    function _setVerifierStatus(address verifier, bool enabled) internal {
        allowedVerifiers[verifier] = enabled;

        emit SetVerifierStatus(verifier, enabled);
    }

    /// @notice Function with withdraw funds from gas tank to migrate them
    /// @dev (only from owner)
    function withdraw(uint256 amount) external onlyOwner {
        if (amount == 0) {
            amount = address(this).balance;
        }
        (bool success, ) = address(msg.sender).call{value: amount}("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    /** Public functions */

    /// @notice Public function to fund this contract, logs out when contract is funded
    function fund() external payable {
        emit ContractFunded(msg.sender, msg.value);
    }

    /// Hashes a permit in the to create a digest that is to be signed.
    /// @param sponsorship the sponsorship to hash
    function hashSponsoredMint(SponsoredMintBatch memory sponsorship) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                SPONSORSHIP_TYPEHASH /* good */,
                sponsorship.verifier,
                sponsorship.from,
                sponsorship.destination,
                keccak256(sponsorship.data),
                sponsorship.expectedRedeemAmount,
                sponsorship.totalAmount,
                keccak256(abi.encodePacked(sponsorship.ids)),
                keccak256(abi.encodePacked(sponsorship.quantities)),
                sponsorship.nonce,
                sponsorship.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    function hashSponsoredSpend(SponsoredSpend memory sponsoredSpend) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                SPONSORED_SPEND_TYPEHASH,
                sponsoredSpend.verifier,
                sponsoredSpend.from,
                sponsoredSpend.destination,
                keccak256(sponsoredSpend.data),
                sponsoredSpend.expectedInputAmount,
                sponsoredSpend.totalAmount,
                sponsoredSpend.nonce,
                sponsoredSpend.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    /** ERC1155 Callback Functions */

    function onERC1155Received(address, address from, uint256 id, uint256 value, bytes calldata data) external onlySparks returns (bytes4) {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);

        ids[0] = id;
        values[0] = value;
        _onBatchReceived(from, ids, values, data);

        return ON_ERC1155_RECEIVED_HASH;
    }

    function _checkSignatureDeadlineNonceVerifier(SponsoredMintBatch memory sponsoredMint) internal {
        // Check nonce
        if (usedNonces[sponsoredMint.verifier][sponsoredMint.nonce]) {
            revert NonceUsed();
        }

        // Mark nonce as used
        usedNonces[sponsoredMint.verifier][sponsoredMint.nonce] = true;

        // Check deadline
        if (sponsoredMint.deadline < block.timestamp) {
            revert SignatureExpired();
        }

        // Check verifier
        if (!allowedVerifiers[sponsoredMint.verifier]) {
            revert VerifierNotAllowed(sponsoredMint.verifier);
        }
    }

    function sponsoredExecute(SponsoredSpend memory sponsoredSpend, bytes memory signature) external payable {
        if (usedNonces[sponsoredSpend.verifier][sponsoredSpend.nonce]) {
            revert NonceUsed();
        }

        usedNonces[sponsoredSpend.verifier][sponsoredSpend.nonce] = true;

        if (sponsoredSpend.deadline < block.timestamp) {
            revert SignatureExpired();
        }

        if (!allowedVerifiers[sponsoredSpend.verifier]) {
            revert VerifierNotAllowed(sponsoredSpend.verifier);
        }

        if (msg.sender != sponsoredSpend.from) {
            revert SenderNotAllowedInSignature();
        }

        if (!SignatureChecker.isValidSignatureNow(sponsoredSpend.verifier, hashSponsoredSpend(sponsoredSpend), signature)) {
            revert InvalidSignature();
        }

        // Check amount received from the unwrap
        if (msg.value != sponsoredSpend.expectedInputAmount) {
            revert RedeemAmountIsIncorrect(sponsoredSpend.expectedInputAmount, transientReceivedAmount);
        }

        uint256 sponsorAmount = sponsoredSpend.totalAmount - sponsoredSpend.expectedInputAmount;

        if (sponsorAmount > address(this).balance) {
            revert NoMoreFundsToSponsor();
        }

        // Event for indexing
        emit SentSponsoredCallFromMintBalances(sponsoredSpend.verifier, sponsoredSpend.from, sponsorAmount, address(this).balance);

        // Send sponsored call
        (bool success, bytes memory callResponseData) = sponsoredSpend.destination.call{value: sponsoredSpend.totalAmount}(sponsoredSpend.data);
        if (!success) {
            revert CallFailed(callResponseData);
        }
    }

    function _onBatchReceived(address, uint256[] memory ids, uint256[] memory quantities, bytes calldata data) internal resetTransientEthReceived {
        if (bytes4(data[:4]) != ISponsoredSparksSpenderAction.sponsoredMintBatch.selector) {
            revert UnknownAction();
        }

        (SponsoredMintBatch memory sponsoredMint, bytes memory signature) = abi.decode(data[4:], (SponsoredMintBatch, bytes));

        _checkSignatureDeadlineNonceVerifier(sponsoredMint);

        if (!SignatureChecker.isValidSignatureNow(sponsoredMint.verifier, hashSponsoredMint(sponsoredMint), signature)) {
            revert InvalidSignature();
        }

        // redeem the Sparks - all eth will be sent to this contract
        Redemption[] memory redemptions = zoraSparks1155.redeemBatch(ids, quantities, address(this));

        // if any redemption is erc20, revert
        for (uint256 i = 0; i < redemptions.length; i++) {
            if (redemptions[i].tokenAddress != address(0)) {
                revert ERC20NotSupported(ids[i]);
            }
        }

        // Validate tokens being sent
        if (sponsoredMint.ids.length != sponsoredMint.quantities.length) {
            revert LengthMismatch();
        }
        for (uint256 i = 0; i < ids.length; i++) {
            if (sponsoredMint.ids[i] != ids[i]) {
                revert IdsMismatch();
            }
            if (sponsoredMint.quantities[i] != quantities[i]) {
                revert ValuesMismatch();
            }
        }

        // Check amount received from the unwrap
        if (transientReceivedAmount != sponsoredMint.expectedRedeemAmount) {
            revert RedeemAmountIsIncorrect(sponsoredMint.expectedRedeemAmount, transientReceivedAmount);
        }

        // Event for indexing
        emit SentSponsoredCallFromMintBalances(
            sponsoredMint.verifier,
            sponsoredMint.from,
            sponsoredMint.totalAmount - sponsoredMint.expectedRedeemAmount,
            address(this).balance
        );

        // Send sponsored call
        (bool success, bytes memory callResponseData) = sponsoredMint.destination.call{value: sponsoredMint.totalAmount}(sponsoredMint.data);
        if (!success) {
            revert CallFailed(callResponseData);
        }
    }

    function onERC1155BatchReceived(
        address,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external onlySparks returns (bytes4) {
        _onBatchReceived(from, ids, values, data);

        // Validate receiving 1155 tokens in callback
        return ON_ERC1155_BATCH_RECEIVED_HASH;
    }

    /// @notice 1155 receive function that just catalogs the amount received
    /// @dev In the case of cross-chain minting this address can be the return address and we want to be able to receive
    /// ETH in order to send it back to the proper owners.
    receive() external payable {
        transientReceivedAmount += msg.value;
    }
}
