// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Enjoy} from "_imagine/mint/Enjoy.sol";
import {IFixedPriceAllowedMintersStrategy} from "../../interfaces/IFixedPriceAllowedMintersStrategy.sol";
import {IMinter1155} from "../../interfaces/IMinter1155.sol";
import {ICreatorCommands} from "../../interfaces/ICreatorCommands.sol";
import {SaleStrategy} from "../SaleStrategy.sol";
import {SaleCommandHelper} from "../utils/SaleCommandHelper.sol";
import {LimitedMintPerAddress} from "../utils/LimitedMintPerAddress.sol";
import {IMinterErrors} from "../../interfaces/IMinterErrors.sol";

/*


             ░░░░░░░░░░░░░░              
        ░░▒▒░░░░░░░░░░░░░░░░░░░░        
      ░░▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░      
    ░░▒▒▒▒░░░░░░░░░░░░░░    ░░░░░░░░    
   ░▓▓▒▒▒▒░░░░░░░░░░░░        ░░░░░░░    
  ░▓▓▓▒▒▒▒░░░░░░░░░░░░        ░░░░░░░░  
  ░▓▓▓▒▒▒▒░░░░░░░░░░░░░░    ░░░░░░░░░░  
  ░▓▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░  
  ░▓▓▓▓▓▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░  
   ░▓▓▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░  
    ░░▓▓▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░    
    ░░▓▓▓▓▓▓▒▒▒▒▒▒▒▒░░░░░░░░░▒▒▒▒▒░░    
      ░░▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░      
          ░░▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░          

               OURS TRULY,


    github.com/ourzora/zora-1155-contracts

*/

/// @title FixedPriceAllowedMintersStrategy
/// @notice A sale strategy for fixed price sales from an allowed set of minters
contract FixedPriceAllowedMintersStrategy is Enjoy, SaleStrategy, LimitedMintPerAddress, IMinterErrors, IFixedPriceAllowedMintersStrategy {
    using SaleCommandHelper for ICreatorCommands.CommandSet;

    /// @notice The sales configs for a given token
    /// @dev 1155 contract -> 1155 tokenId -> settings
    mapping(address => mapping(uint256 => SalesConfig)) internal salesConfigs;

    /// @notice If an address is allowed to mint a given token
    /// @dev 1155 contract => 1155 tokenId => minter address => allowed
    mapping(address => mapping(uint256 => mapping(address => bool))) internal allowedMinters;

    /// @notice If a minter address is allowed to mint a token
    /// @param tokenContract The 1155 contract address
    /// @param tokenId The 1155 token id
    /// @param minter The minter address
    function isMinter(address tokenContract, uint256 tokenId, address minter) public view returns (bool) {
        return allowedMinters[tokenContract][tokenId][minter] || allowedMinters[tokenContract][0][minter];
    }

    /// @notice Sets the allowed addresses that can mint a given token
    /// @param tokenId The tokenId to set the minters for OR tokenId 0 to set the minters for all tokens contract-wide
    /// @param minters The list of addresses to set permissions for
    /// @param allowed Whether allowing or removing permissions for the minters
    function setMinters(uint256 tokenId, address[] calldata minters, bool allowed) external {
        uint256 numMinters = minters.length;

        for (uint256 i; i < numMinters; ++i) {
            allowedMinters[msg.sender][tokenId][minters[i]] = allowed;

            emit MinterSet(msg.sender, tokenId, minters[i], allowed);
        }
    }

    /// @notice Sets the sale config for a given token
    /// @param tokenId The token id to set the sale config for
    /// @param salesConfig The sales config to set
    function setSale(uint256 tokenId, SalesConfig calldata salesConfig) external {
        if (salesConfig.saleStart >= salesConfig.saleEnd) {
            revert InvalidSaleTime();
        }
        salesConfigs[msg.sender][tokenId] = salesConfig;

        emit SaleSet(msg.sender, tokenId, salesConfig);
    }

    /// @notice Deletes the sale config for a given token
    /// @param tokenId The token id to delete the sale config for
    function resetSale(uint256 tokenId) external override {
        delete salesConfigs[msg.sender][tokenId];

        // Deleted sale emit event
        emit SaleSet(msg.sender, tokenId, salesConfigs[msg.sender][tokenId]);
    }

    /// @notice Compiles and returns the commands needed to mint a token using this sales strategy
    /// @param mintMsgSender The address that called the mint on the 1155 contract
    /// @param tokenId The token ID to mint
    /// @param quantity The quantity of tokens to mint
    /// @param ethValueSent The amount of ETH sent with the transaction
    /// @param minterArguments The arguments passed to the minter, which should be the address to mint to
    function requestMint(
        address mintMsgSender,
        uint256 tokenId,
        uint256 quantity,
        uint256 ethValueSent,
        bytes calldata minterArguments
    ) external returns (ICreatorCommands.CommandSet memory commands) {
        // Ensure the minter is allowed to mint either this token or all tokens contract-wide
        if (!isMinter(msg.sender, tokenId, mintMsgSender)) {
            revert ONLY_MINTER();
        }

        address mintTo;
        string memory comment = "";

        if (minterArguments.length == 32) {
            mintTo = abi.decode(minterArguments, (address));
        } else {
            (mintTo, comment) = abi.decode(minterArguments, (address, string));
        }

        SalesConfig storage config = salesConfigs[msg.sender][tokenId];

        // If sales config does not exist this first check will always fail.

        // Check sale end
        if (block.timestamp > config.saleEnd) {
            revert SaleEnded();
        }

        // Check sale start
        if (block.timestamp < config.saleStart) {
            revert SaleHasNotStarted();
        }

        // Check value sent
        if (config.pricePerToken * quantity != ethValueSent) {
            revert WrongValueSent();
        }

        bool shouldTransferFunds = config.fundsRecipient != address(0);
        commands.setSize(shouldTransferFunds ? 2 : 1);

        // Mint command
        commands.mint(mintTo, tokenId, quantity);

        if (bytes(comment).length > 0) {
            emit MintComment(mintTo, msg.sender, tokenId, quantity, comment);
        }

        // Should transfer funds if funds recipient is set to a non-default address
        if (shouldTransferFunds) {
            commands.transfer(config.fundsRecipient, ethValueSent);
        }
    }

    /// @notice Returns the sale config for a given token
    function sale(address tokenContract, uint256 tokenId) external view returns (SalesConfig memory) {
        return salesConfigs[tokenContract][tokenId];
    }

    /// @notice The version of the sale strategy
    function contractVersion() external pure override returns (string memory) {
        return "1.0.1";
    }

    function contractURI() external pure override returns (string memory) {
        return "https://github.com/ourzora/zora-protocol/";
    }

    /// @notice The name of the sale strategy
    function contractName() external pure override returns (string memory) {
        return "Fixed Price Allowed Minters Strategy";
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual override(LimitedMintPerAddress, SaleStrategy) returns (bool) {
        return super.supportsInterface(interfaceId) || LimitedMintPerAddress.supportsInterface(interfaceId) || SaleStrategy.supportsInterface(interfaceId);
    }
}
