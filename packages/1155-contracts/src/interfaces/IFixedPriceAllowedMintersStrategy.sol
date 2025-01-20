// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFixedPriceAllowedMintersStrategy {
    /// @notice If a minter address is allowed to mint a token
    /// @param tokenContract The 1155 contract address
    /// @param tokenId The 1155 token id
    /// @param minter The minter address
    function isMinter(address tokenContract, uint256 tokenId, address minter) external view returns (bool);

    /// @notice Sets the allowed addresses that can mint a given token
    /// @param tokenId The tokenId to set the minters for OR tokenId 0 to set the minters for all tokens contract-wide
    /// @param minters The list of addresses to set permissions for
    /// @param allowed Whether allowing or removing permissions for the minters
    function setMinters(uint256 tokenId, address[] calldata minters, bool allowed) external;

    /// @notice Sets the sale config for a given token
    /// @param tokenId The token id to set the sale config for
    /// @param salesConfig The sales config to set
    function setSale(uint256 tokenId, SalesConfig calldata salesConfig) external;

    struct SalesConfig {
        /// @notice Unix timestamp for the sale start
        uint64 saleStart;
        /// @notice Unix timestamp for the sale end
        uint64 saleEnd;
        /// @notice Max tokens that can be minted for an address, 0 if unlimited
        uint64 maxTokensPerAddress;
        /// @notice Price per token in eth wei
        uint96 pricePerToken;
        /// @notice Funds recipient (0 if no different funds recipient than the contract global)
        address fundsRecipient;
    }

    event SaleSet(address indexed mediaContract, uint256 indexed tokenId, SalesConfig salesConfig);
    event MintComment(address indexed sender, address indexed tokenContract, uint256 indexed tokenId, uint256 quantity, string comment);
    event MinterSet(address indexed mediaContract, uint256 indexed tokenId, address indexed minter, bool allowed);

    error ONLY_MINTER();
    error InvalidSaleTime();
}
