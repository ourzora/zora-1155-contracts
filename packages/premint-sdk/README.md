# Premint SDK

Premint SDK allows users to manage zora premints

### Creating a premint:

```js
import {PremintAPI} from '@zoralabs/premint-sdk';

async function makePremint(walletClient: WalletClient) {
    // Create premint API object passing in the current wallet chain (only zora and zora testnet are supported currently).
    const premintAPI = new PremintAPI(walletClient.chain);

    // Create premint
    const premint = await premintAPI.createPremint({
        // Extra step to check the signature on-chain before attempting to sign
        checkSignature: true,
        // Collection information that this premint NFT will exist in once minted.
        collection: {
            contractAdmin: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            contractName: "Testing Contract",
            contractURI: "ipfs://bafkreiainxen4b4wz4ubylvbhons6rembxdet4a262nf2lziclqvv7au3e",
        },
        // WalletClient doing the signature
        walletClient,
        // Token information, falls back to defaults set in DefaultMintArguments.
        token: {
            tokenURI:
            "ipfs://bafkreice23maski3x52tsfqgxstx3kbiifnt5jotg3a5ynvve53c4soi2u",
        },
    });

    console.log(`created ZORA premint, link: ${premint.url}`)
    return premint;
}

```

### Executing a premint:

```js
import {PremintAPI} from '@zoralabs/premint-sdk';

async function executePremint(walletClient: WalletClient, premintAddress: Address, premintUID: number) {
    const premintAPI = new PremintAPI(walletClient.chain);

    return await premintAPI.executePremintWithWallet({
        data: premintAPI.getPremintData(premintAddress, premintUID),
        walletClient,
        mintArguments: {
            quantityToMint: 1,
        }
    });
}

```

### Deleting a premint:

```js
import {PremintAPI} from '@zoralabs/premint-sdk';

async function deletePremint(walletClient: WalletClient, collection: Address, uid: number) {
    const premintAPI = new PremintAPI(walletClient.chain);

    return await premintAPI.deletePremint({
        walletClient,
        uid,
        collection
    });
}

```
