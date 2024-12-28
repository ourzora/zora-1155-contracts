# @zoralabs/protocol-sdk

## 0.11.12

### Patch Changes

- Updated dependencies [fc8e86a8]
  - @zoralabs/protocol-deployments@0.4.0

## 0.11.11

### Patch Changes

- ff8084fe: Updates `minimumMintsForCountdown` and `mintCount` calculations to use the updated 0.0000222 ETH market reward live in v2.2.0 of the timed sale strategy
- 2ce16ac7: Move from allowlist.zora.co to lanyard.org for allowlist manager service
- Updated dependencies [ff8084fe]
  - @zoralabs/protocol-deployments@0.3.11

## 0.11.10

### Patch Changes

- a1137e35: saleStart defaults to current timestamp in seconds
- Updated dependencies [abbd6333]
  - @zoralabs/protocol-deployments@0.3.10

## 0.11.9

### Patch Changes

- 9d5d1638: When minting + commenting, and using the timed sale strategy, protocol sdk will call the CallerAndCommenter contract
- 088ec6fb: When buying on secondary, you can now add a comment, which will call the CallerAndCommenter's buyOnSecondaryAndComment function.
- Updated dependencies [4928687d]
  - @zoralabs/protocol-deployments@0.3.9

## 0.11.8

### Patch Changes

- 330f1131: Fix royalties queries to filter by erc20z that have secondary activated

## 0.11.7

### Patch Changes

- 041871d7: Fix royalties query for secondary tokens to query subgraph for royaltyRecipient instead of user.

## 0.11.6

### Patch Changes

- Updated dependencies [ad707434]
- Updated dependencies [2e68a87c]
- Updated dependencies [17cc9821]
  - @zoralabs/protocol-deployments@0.3.8

## 0.11.5

### Patch Changes

- 85d09fa5: - Adds new fields to `SecondaryInfo` type to expose more information about the secondary market configuration:

  - `name`: The ERC20Z token name
  - `symbol`: The ERC20Z token symbol
  - `saleStart`: Earliest time tokens can be minted
  - `marketCountdown`: Time after minimum mints reached until secondary market launches
  - `minimumMintsForCountdown`: Minimum mints required to start countdown
  - `mintCount`: Total number of tokens minted so far
  - Deprecates `minimumMarketEth` parameter in favor of `minimumMintsForCountdown` when creating tokens:
    - `minimumMintsForCountdown` directly specifies minimum number of mints (defaults to `1111`)
    - `minimumMarketEth` is still supported but calculated internally as `minimumMintsForCountdown * 0.0000111 ETH`

- Updated dependencies [c08ec3b3]
  - @zoralabs/protocol-deployments@0.3.7

## 0.11.4

### Patch Changes

- Updated dependencies [d6aa9a00]
  - @zoralabs/protocol-deployments@0.3.6

## 0.11.3

### Patch Changes

- 364d7906: Change DEFAULT_MINIMUM_MARKET_ETH to 0.0123321 eth (1,111 mints) to match default that is set on zora.co
- e68ce881: Fix filtering for active markets
- 4a29c2b9: Bump viem to 2.21.21
- Updated dependencies [4a29c2b9]
  - @zoralabs/protocol-deployments@0.3.5

## 0.11.2

### Patch Changes

- 66f33bbb: fix: update secondary swap helper contract address
- 8d7fdc02: For the functions `getToken` and `getTokensOfContract`, the returned `MintableReturn` type has been updated to provide more information about the primary mint status:

  - Added `primaryMintActive` boolean to indicate if the primary mint is currently active.
  - Added `primaryMintEnd` optional `bigint` to show the end time of the primary mint, if applicable.
  - Added `secondaryMarketActive` boolean to indicate if the secondary market is currently active.
  - Modified `prepareMint` to be conditionally available:
    - When `primaryMintActive` is `true`, `prepareMint` is available as a `PrepareMint` function.
    - When `primaryMintActive` is `false`, `prepareMint` is set to `undefined`.

  This allows for developers to know if the primary mint is active or not, and if not, if they should buy on secondary.

- Updated dependencies [66f33bbb]
  - @zoralabs/protocol-deployments@0.3.4

## 0.11.1

### Patch Changes

- Updated dependencies [b885539f]
  - @zoralabs/protocol-deployments@0.3.3

## 0.11.0

### Minor Changes

- 21247473: Added new functions `buy1155OnSecondary` and `sell1155OnSecondary` to the collector client in the protocol SDK. These functions enable users to buy and sell ERC1155 tokens on the secondary market. Key features include:

  - Slippage protection for both buying and selling operations
  - Detailed price breakdowns in wei, sparks, and USDC
  - Support for specifying recipient addresses
  - Error handling and simulation parameters

## 0.10.0

### Minor Changes

- fc4a7f65: Support viewing and withdrawing protocol rewards and secondary royalties balances from the sdk, using the new methods `getRewardsBalances` and `withdrawRewards`.

## 0.9.6

### Patch Changes

- 24520e9a: Fix sdk setSale for v2 params
- Updated dependencies [247ebc86]
- Updated dependencies [24520e9a]
  - @zoralabs/protocol-deployments@0.3.2

## 0.9.5

### Patch Changes

- 879a019a: - Fixed types, defaults, and queries for v2 timed sales

## 0.9.4

### Patch Changes

- b9fcab20: Removed unneeded async in token setup
- Updated dependencies [d221894d]
- Updated dependencies [f94e5f03]
- Updated dependencies [1b4d5ee7]
  - @zoralabs/protocol-deployments@0.3.1

## 0.9.3

### Patch Changes

- c75eb65b: Fix bug where for timed sale strategy, sales settings were not being set. For getting default erc20 name, get it from the contract name instead of fetching from ipfs.

## 0.9.2

### Patch Changes

- 5f964909: To speed up performance for `create1155OnExistingContract`, use subgraph to get contract info and reduce quantity of rpc reads.

## 0.9.1

### Patch Changes

- f40c4a8f: `create1155` and `create1155OnExistingContract` return an async `prepareMint` function, enabling to mint right after creating without needing to rely on the subgraph.

## 0.9.0

### Minor Changes

- 8c50a99c: Add support for creating 1155s and collecting using the new ZoraTimedSaleStrategy. Default to using the new ZoraTimedSaleStrategy as a minter for new 1155s.

### Patch Changes

- 47c20f4d: - Added support for allowlist mint creation and collection
  - For creating an erc20 mint, the parameter `type` must be set to `erc20Mint` on the `token.salesConfig` object

## 0.8.0

### Minor Changes

- 5417f4dd: ProtocolSdk `create1155` can only be used for new contracts, and returns the correct deterministic contract address. A new function `create1155OnExistingContract` is added to support creating 1155 tokens on existing contracts

## 0.7.6

### Patch Changes

- Updated dependencies [58f59243]
- Updated dependencies [b5a7fac4]
  - @zoralabs/protocol-deployments@0.3.0

## 0.7.5

### Patch Changes

- 12909b5b: Renamed Mints to Sparks
- Updated dependencies [12909b5b]
- Updated dependencies [58914a0c]
  - @zoralabs/protocol-deployments@0.2.2

## 0.7.4

### Patch Changes

- 527aa518: Move from yarn to pnpm properly pinning deps packages
- Updated dependencies [527aa518]
  - @zoralabs/protocol-deployments@0.2.1

## 0.7.3

### Patch Changes

- 898c84a7: [chore] Update dependencies and runtime scripts

  This ensures jobs do not match binary names to make runs less ambiguous and also that all deps are accounted for.

- Updated dependencies [898c84a7]
- Updated dependencies [0ec838a4]
- Updated dependencies [e0b5074d]
  - @zoralabs/protocol-deployments@0.2.0

## 0.7.2

### Patch Changes

- cd5ac235: protocol sdk gets mint price from the default mint price entity on the subgraph

## 0.7.1

### Patch Changes

- 5c009569: Added metadata builder methods to sdk. sdk's method createPremint returns collect/manage urls

## 0.7.0

### Minor Changes

- f52f28f3: Added methods to Collector Client: getToken, getTokensOfContract

## 0.6.0

### Minor Changes

- 8c23f05b: - new high-level sdks: `createCreatorClient` and `createCollectorClient`. `createPremintClient`, `createMintClient`, `create1155CreatorClient`, and `createPremintClient` are removed.
  - external apis, such as the premint api can be stubbed/replaced/mocked.
  - new function `mint` on the collector sdk that works with `1155`, `premint`, and `721`s.
  - `create1155` now supports creating erc20, free, and paid mints. Setup actions now mimic what's on zora.co.

### Patch Changes

- b0f0fb74: premintClient - fix default mint duration to be unlimited (it was one week before)

## 0.5.17

### Patch Changes

- b16078bc:
  - premintClient now supports creating/minting premints with additional admins.
  - premint client supports creating premints with just a collection address, as long as the premint has been brought onchain
- 502f3295: premint sdk - on createPremint, `payoutRecipient` argument moved to `tokenCreationConfig`. premintConfigVersion is no longer an argument; the sdk automatically figures out which is the appropriate version
- Updated dependencies [9cdd81ac]
  - @zoralabs/protocol-deployments@0.1.13

## 0.5.16

### Patch Changes

- 12387133: `create1155CreatorClient` requires `chain` to be passed as a default argument instead of a `publicClient`
- Updated dependencies [7af9c4db]
  - @zoralabs/protocol-deployments@0.1.12

## 0.5.15

### Patch Changes

- 888168b8: Fix protocol-sdk to point to `isAuthorizedToCreatePremint`
- 344f452b: Add support for ERC-20 minting on 1155s using ERC20 minters within the function `makePrepareMintTokenParams`.

## 0.5.14

### Patch Changes

- 1a4aa02d: Remove graphql-request library and add base sepolia
- Updated dependencies [399ba552]
  - @zoralabs/protocol-deployments@0.1.11

## 0.5.13

### Patch Changes

- 16deff0c: Moved typed data definitions from protocol-sdk to protocol-deployments
- Updated dependencies [16deff0c]
  - @zoralabs/protocol-deployments@0.1.10

## 0.5.12

### Patch Changes

- e2452f7d: Removed `zora-1155-contracts`, `1155-deployments`, `mints-contracts`, and `mints-deployments` from devDependencies hierarchy.

## 0.5.11

### Patch Changes

- 8e514b7: Cleanup protocol-sdk to have better docs around all methods, and remove methods that do not need to be exported and are not used.
- 598a95b: Bumps protocol-sdk to use viem@2.x- see the [viem 2.X.X migration guide](https://viem.sh/docs/migration-guide#2xx-breaking-changes) for breaking changes when migratring from viem 1.X.X to 2.X.X
- Updated dependencies [8e514b7]
  - @zoralabs/protocol-deployments@0.1.8

## 0.5.10

### Patch Changes

- Updated dependencies [9a16b81]
  - @zoralabs/protocol-deployments@0.1.6

## 0.5.9

### Patch Changes

- 825e5f7: Adds optional `createReferral` to `createNew1155Token` params

## 0.5.8

### Patch Changes

- 50a4e09: Added sdk method to get total MINT balance
- Updated dependencies [042edbe]
- Updated dependencies [50a4e09]
  - @zoralabs/protocol-deployments@0.1.5

## 0.5.7

### Patch Changes

- 2eda168: Update default premint version to v2
- 4066420: Adding protocol SDK to base and sepolia networks
- Updated dependencies [bb163d3]
  - @zoralabs/protocol-deployments@0.1.3

## 0.5.6

### Patch Changes

- 52b16aa: Publishing package in format that supports commonjs imports by specifying exports
- Updated dependencies [52b16aa]
  - @zoralabs/protocol-deployments@0.1.2

## 0.5.5

### Patch Changes

- 8a87809: Undo changes to package export because it didn't properly bundle all files in `dist`

## 0.5.4

### Patch Changes

- 9710e5e: Defining exports in protocol-sdk

## 0.5.3

### Patch Changes

- a07499d: Allows an `Account` object to be passed for `signTypedData` compatibility with Local Accounts

## 0.5.2

### Patch Changes

- 5c536dc: Update optimism eth constant
- Updated dependencies [f3332ee]
- Updated dependencies [d2085fd]
- Updated dependencies [a51a0cb]
  - @zoralabs/1155-deployments@0.0.13

## 0.5.1

### Patch Changes

- 73070c0:
  - Fix types export - make sure that types are exported to the correct directory. Broken by commit 627f8c37716f0b5c201f75ab1d025ae878be0ae29e7a269d21185fa04e4bcf93
  - Exclude tests from built bundle
  - Fixes #396

## 0.5.0

### Minor Changes

- a52d245: Fix premint v2 support in premint client and add support for sepolia to SDK:

  - Fix chain constants config for Zora Goerli.
  - Support Zora-Sepolia for premint client.
  - Fix passing of `config_version` to and from the backend API.
  - Change parameter on `makeMintParameters` from `account` to `minterAccount`.
  - Fix price minter address for premint client by chain, since it is not the same on all chains (yet).

### Patch Changes

- Updated dependencies [3af77cf]
- Updated dependencies [23dba1c]
  - @zoralabs/protocol-deployments@0.0.12

## 0.4.3

### Patch Changes

- 92b1b0e: Export premint conversions

## 0.4.2

### Patch Changes

- 9b03ed2: Support premint v2 in sdk
- Updated dependencies [bff853a]
  - @zoralabs/protocol-deployments@0.0.11

## 0.4.1

### Patch Changes

- 7e00197: \* For premintV1 and V2 - mintReferrer has been changed to an array `mintRewardsRecipients` - which the first element in array is `mintReferral`, and second element is `platformReferral`. `platformReferral is not used by the premint contract yet`.
- 0ceb709: Add mint costs getter for premint to protocol sdk
- Updated dependencies [5156b9e]
  - @zoralabs/protocol-deployments@0.0.9

## 0.4.0

### Minor Changes

- 28884c9: \* `PremintClient` now takes a premint config v1 or v2, and a premint config version, for every call to create/update/delete a premint. PremintClient methods have been simplified and are easier to use - for example `createPremint` no longer allows to specify `deleted` = true. For `makeMintParameters` - it now just takes the uid and contract address (instead of full premint config)
  - `PremintAPIClient` now converts entities to contract entities before returning them, and correspondingly expects them as contract entities when passed in. It internally converts them to backend entities before sending them to the backend.

### Patch Changes

- Updated dependencies [4b77307]
  - @zoralabs/protocol-deployments@0.0.8

## 0.3.5

### Patch Changes

- 7eb5e3f: ### Changes to `preminter`

  lower level `preminter.ts` now supports premint v2 by defining v2 typed data definitions.

  - `isValidSignature` now takes either v1 or v2 of a premint config, along with the premint config version. and both recovers the signer address and validates if the signer can create a premint on the given contract.
  - new function `premintTypedDataDefinition` which takes a premint config version and returns the signable typed data definition for that version
  - new function `recoverCreatorFromCreatorAttribution` which recovers the creator address from a `CreatorAttribution` event
  - new function `supportsPremintVersion` which checks if a given token contract supports a given premint config version
  - new function `tryRecoverPremintSigner` which takes a premint config version and a premint signature, and tries to recover the signer address from the signature. If the signature is invalid, it returns undefined.

  ### Changes to PremintClient

  `PremintClient` creation, updating, and deletion now take both premint config v1 and v2, but currently rejects them until the backend api supports creating v2 premints.

  - `isValidSignature` now just takes the data directly as a param, instead of `{data}`

- 27a2e23: Fix reading the FIXED_PRICE_MINTER from the subgraph

## 0.3.4

### Patch Changes

- ea27f01: Fix reading the FIXED_PRICE_MINTER from the subgraph

## 0.3.3

### Patch Changes

- 97f58b3: `MintAPIClient` is now a class, that takes a chain id and httpClient in the constructor, enabling the httpClient methods `fetch`, `post`, and `retries` to be overridden.

  new methods on `MintAPIClient`:

  `getMintableForToken` - takes a token id and token contract address and returns the mintable for it. Easier to use for fetching specific tokens than `getMintable`.

  `MintClient` now takes the optional `PublicClient` in the constructor instead of in each function, and stores it or creates a default one if none is provided in the constructor. It also takes an optional `httpClient` param in the constructor, allowing the `fetch`, `post`, and `retries` methods to be overridden when using the api. It now internally creates the MintAPIClient.

  `MintClient.makePrepareMintTokenParams` has the following changes:

  - returns a `SimulateContractParams`, instead of an object containing it indexed by key
  - no longer takes a `PublicClient` as an argument (it should be specified in the constructor instead)

  new function `MintClient.getMintCosts` takes a mintable and quantity to mint and returns the mintFee, paidMintPrice, and totalCost.

- d02484e: premintClient can have http methods overridable via DI, and now takes publicClient and http overrides in `createPremintClient` function. it no longer takes `publicClient` as an argument in functions, and rather uses them from the constructor. `executePremint` has been renamed ot `makeMintParameters`

## 0.3.2

### Patch Changes

- de0b0b7: `preminter` exposes new function isValidSignatureV1 that recovers a signer from a signed premint and determines if that signer is authorized to sign
- Updated dependencies [f3b7df8]
  - @zoralabs/protocol-deployments@0.0.6

## 0.3.1

### Patch Changes

- 92da3ed: Exporting mint client
- Updated dependencies [293e2c0]
  - @zoralabs/protocol-deployments@0.0.5

## 0.3.0

### Minor Changes

- 40e0b32:
  - rename premint-sdk to protocol-sdk
  - added minting sdk, usable with `createMintClient`
  - added 1155 creation sdk, usable with `create1155CreatorClient`
  - premint sdk is now useable with `createPremintClient`

## 0.1.1

### Patch Changes

- b62e471: created new package `protocol-deployments` that includes the deployed contract addresses.

  - 1155-contracts js no longer exports deployed addresses, just the abis
  - premint-sdk imports deployed addresses from `protocol-deployments

- Updated dependencies [4d79b49]
- Updated dependencies [b62e471]
- Updated dependencies [7d1a4c1]
  - @zoralabs/protocol-deployments@0.0.2

## 0.1.0

### Minor Changes

- 4afa879: Added new premint api that abstracts out calls to the chain signature and submission logic around submitting a premint. This change also incorporates test helpers for premints and introduces docs and an api client for the zora api's premint module.

### Patch Changes

- Updated dependencies [4afa879]
  - @zoralabs/zora-1155-contracts@2.3.0

## 0.0.2-premint-api.2

### Patch Changes

- c29e080: Update retry and error reporting

## 0.0.2-premint-api.1

### Patch Changes

- 6eaf7bb: add retries

## 0.0.2-premint-api.0

### Patch Changes

- Updated dependencies [8395b8e]
- Updated dependencies [aae756b]
- Updated dependencies [cf184b3]
  - @zoralabs/zora-1155-contracts@2.1.1-premint-api.0
