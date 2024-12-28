// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IERC20Z is IERC20Metadata {
    /// @notice TokenInfo struct returned by the information function
    struct TokenInfo {
        /// @notice The collection address
        address collection;
        /// @notice The token ID
        uint256 tokenId;
        /// @notice The creator address
        address creator;
    }

    /// @notice Event for when the ERC1155s are directly converted to ERC20Zs
    /// @param erc20z ERC20Z Address
    /// @param amount20z ERC20Z Amount
    /// @param collection Collection address
    /// @param tokenId ID for the ERC1155 token swapped
    /// @param amount1155 Amount of 1155 converted
    /// @param recipient Recipient of the conversion
    event ConvertedTo20z(address indexed erc20z, uint256 amount20z, address collection, uint256 tokenId, uint256 amount1155, address recipient);

    /// @notice Event for when ERC20Zs are directly converted to ERC1155
    /// @param erc20z ERC20Z Address
    /// @param amount20z ERC20Z Amount
    /// @param collection Collection address
    /// @param tokenId ID for the ERC1155 token swapped
    /// @param amount1155 Amount of 1155 converted
    /// @param recipient Recipient of the conversion
    event ConvertedTo1155(address indexed erc20z, uint256 amount20z, address collection, uint256 tokenId, uint256 amount1155, address recipient);

    /// @notice Event for when the secondary market is activated
    /// @param token0 Token 0 for uniswap liquidity
    /// @param amount0 Amount 0 for uniswap liquidity
    /// @param token1 Token 1 for uniswap liquidity
    /// @param amount1 Amount 1 for uniswap liquidity
    /// @param fee Uniswap fee amount
    /// @param positionId ERC721 Position ID for the default liquidity
    /// @param lpLiquidity amount of lp liquidity held by this contract
    /// @param erc20Excess ERC20 excess amount burned
    /// @param erc1155Excess ERC1155 excess amount burned
    event SecondaryMarketActivated(
        address indexed token0,
        uint256 indexed amount0,
        address token1,
        uint256 amount1,
        uint256 fee,
        uint256 positionId,
        uint256 lpLiquidity,
        uint256 erc20Excess,
        uint256 erc1155Excess
    );

    /// @notice Event for when admin mint NFTs are received
    /// @param quantity the amount received
    event ReceivedAdminMintNFTs(uint256 quantity);

    /// @notice Errors when attempts to reactivate
    error AlreadyActivatedCannotReactivate();

    /// @notice ERC1155 Ids do not match values length
    error IDsDoNotMatchValuesLength();

    /// @notice Passing in wrong ERC1155 token id to swap
    error TokenIdNotValidToSwap();

    /// @notice Action sent with ERC1155 data call is not known
    error UnknownReceiveActionDataCall();

    /// @notice Only supports receiving ERC721 Pool NFTs
    error OnlySupportReceivingERC721UniswapPoolNFTs();

    /// @notice Error when trying to swap ERC1155 to ERC20Z without the market being started.
    error SecondaryMarketHasNotYetStarted();

    /// @notice Only supports receiving ERC1155 associated with ERC20Z NFTs.
    error OnlySupportReceivingERC1155AssociatedZoraNFT();

    /// @notice Unauthorized to call this function
    error OnlySaleStrategy();

    /// @notice Pool creation failed
    error PoolCreationFailed();

    /// @notice Params are invalid
    error InvalidParams();

    /// @notice Insufficient balance
    error InsufficientBalance();

    /// @notice Invalid amount of ERC20z tokens
    error InvalidAmount20z();

    /// @notice Invalid ERC20z transfer
    error Invalid20zTransfer();

    /// @notice Recipient address cannot be zero
    error RecipientAddressZero();

    /// @notice Token URI
    function tokenURI() external view returns (string memory);

    /// @notice Token information
    function tokenInfo() external view returns (TokenInfo memory);

    /// @notice Returns the ERC20Z contract URI
    function contractURI() external view returns (string memory);

    /// @notice Token liquidity information getter
    function tokenLiquidityInfo() external view returns (address pool, uint256 initialLiquidityPositionId);

    /// @notice Initialize the ERC20Z token
    /// @param collection The collection address
    /// @param tokenId The token ID
    /// @param name The token name
    /// @param symbol The token symbol
    function initialize(address collection, uint256 tokenId, string memory name, string memory symbol) external returns (address);

    /// @notice Activate the ERC20Z token
    /// @param erc20TotalSupply The total supply of the ERC20 token
    /// @param erc20Reserve The reserve of the ERC20 token
    /// @param erc20Liquidity The liquidity of the ERC20 token
    /// @param erc20Excess The excess of the ERC20 token
    /// @param erc1155Excess The excess of the ERC1155 token
    function activate(uint256 erc20TotalSupply, uint256 erc20Reserve, uint256 erc20Liquidity, uint256 erc20Excess, uint256 erc1155Excess) external;

    /// @notice Convert 1155 to ERC20z tokens
    /// @param amount1155 The amount of 1155 tokens to convert
    /// @param recipient The recipient address
    function wrap(uint256 amount1155, address recipient) external;

    /// @notice Convert ERC20z to 1155 tokens
    /// @param amount20z The amount of ERC20z tokens to convert
    /// @param recipient The recipient address
    function unwrap(uint256 amount20z, address recipient) external;
}
