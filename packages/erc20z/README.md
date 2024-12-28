# Zora Timed Sale Strategy

The Zora Sale Timed Sale Strategy introduces a new fixed price and unlocks secondary sales on Uniswap V3. New tokens minted will have a fixed price of 0.000111 ETH (111 sparks).

Upon calling setSale() a sale will be created for the 1155 NFT provided. In this function, it will also create an ERC20z token and a Uniswap V3 Pool. The ERC20z token will be used as a pool pair (WETH / ERC20z) as well as enable wrapping and unwrapping tokens from 1155 to ERC20z and vice versa.

After the sale has ended launchMarket() will be called to launch the secondary market. This will deploy liquidity into the Uniswap V3 pool and enable buying and selling as a result.

## ERC20z

ERC20z is an extension of the ERC20 standard by allowing an ERC20 token to have metadata.

The ERC20z contract also allows users to wrap and unwrap tokens. Wrapping converts a Zora 1155 token to an ERC20z token. Unwrap converts an ERC20z token to a Zora 1155 token.

## Royalties

Royalties contract manages royalty distribution from secondary markets on Uniswap V3. Creators can earn LP liquidity rewards from the Uniswap pool and can collect royalties using the Royalties contract.

## Deployment Deterministic Addresses

- Zora Timed Sale Strategy: 0x777777722D078c97c6ad07d9f36801e653E356Ae
- Royalties: 0x77777771DF91C56c5468746E80DFA8b880f9719F

## Deployment

The `ZoraTimedSaleStrategy`, `Royalties`, and `SecondarySwap` helper contracts are deployed deterministically using a turnkey account. The deployment process uses a helper contract, [DeterministicDeployerAndCaller](../../packages/shared-contracts/src/deployment/DeterministicDeployerAndCaller.sol).

Deployment happens in two steps for each set of contracts:

1. Generate the deterministic deployment configuration (once per contract set).
2. Use the configuration to deploy the contract to any chain using a turnkey-generated signature.

### Prerequisites

- Ensure you have [Forge](https://book.getfoundry.sh/getting-started/installation) installed.
- Familiarity with [turnkey accounts](https://docs.turnkey.com/) is recommended.

### Setting up environment variables

In the `packages/erc20z` directory:

1. Copy `.env.example` to `.env`
2. Populate the parameters in `.env`
3. Set `TURNKEY_TARGET_ADDRESS` to the address of the turnkey account that will sign the deployment.

### Deploying the Zora Timed Sale Strategy and Royalties contracts

1. Generate deterministic config (if not already done):

```bash
DEPLOYER={TURNKEY_DEPLOYER_ADDRESS} forge script script/GenerateDeterministicParams.s.sol $(chains zora --deploy) --ffi
```

This saves the config to `./deterministicConfig/zoraTimedSaleStrategy.json` and `./deterministicConfig/royalties.json`.

2. Deploy the `ZoraTimedSaleStrategyImpl` implementation contract:

```bash
forge script script/DeployImpl.s.sol $(chains {chainName} --deploy) --broadcast --verify
```

3. Deploy the `Royalties` and `ZoraTimedSaleStrategy` contracts:

```bash
forge script script/Deploy.s.sol $(chains {chainName} --deploy) --broadcast --verify --ffi
```

### Deploying the SecondarySwap helper

1. Generate deterministic config (if not already done):

```bash
DEPLOYER={TURNKEY_DEPLOYER_ADDRESS} forge script script/GenerateSecondarySwapDeterministicParams.s $(chains zora --deploy) --ffi
```

This saves the config to `./deterministicConfig/secondarySwap.json`.

2. Deploy the `SecondarySwap` contract:

```bash
forge script script/DeploySwapHelper.s.sol $(chains {chainName} --deploy) --broadcast --verify --ffi
```

Note: Replace `{chainName}` with the target blockchain network (e.g., "zora", "mainnet", etc.) in the deployment commands.

After deployment, verify the contract addresses on the blockchain explorer to ensure successful deployment.
