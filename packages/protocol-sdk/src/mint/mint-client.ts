import {
  Address,
  Chain,
  PublicClient,
  createPublicClient,
  encodeAbiParameters,
  parseAbi,
  parseAbiParameters,
  zeroAddress,
  http,
} from "viem";
import { IHttpClient } from "../apis/http-api-base";
import { MintAPIClient, MintableGetTokenResponse } from "./mint-api-client";
import { SimulateContractParameters } from "viem";
import {
  zoraCreator1155ImplABI,
  zoraCreatorFixedPriceSaleStrategyAddress,
} from "@zoralabs/protocol-deployments";

class MintError extends Error {}
class MintInactiveError extends Error {}

export const Errors = {
  MintError,
  MintInactiveError,
};

type MintArguments = {
  quantityToMint: number;
  mintComment?: string;
  mintReferral?: Address;
  mintToAddress: Address;
};

const zora721Abi = parseAbi([
  "function mintWithRewards(address recipient, uint256 quantity, string calldata comment, address mintReferral) external payable",
  "function zoraFeeForAmount(uint256 amount) public view returns (address, uint256)",
] as const);

class MintClient {
  readonly apiClient: MintAPIClient;
  readonly publicClient: PublicClient;

  constructor(
    chain: Chain,
    publicClient?: PublicClient,
    httpClient?: IHttpClient,
  ) {
    this.apiClient = new MintAPIClient(chain.id, httpClient);
    this.publicClient =
      publicClient || createPublicClient({ chain, transport: http() });
  }

  /**
   * Gets mintable information for a given token
   * @param param0.tokenContract The contract address of the token to mint.
   * @param param0.tokenId The token id to mint.
   * @returns
   */
  async getMintable({
    tokenContract,
    tokenId,
  }: {
    tokenContract: Address;
    tokenId?: bigint | number | string;
  }) {
    return await this.apiClient.getMintableForToken({
      tokenContract,
      tokenId: tokenId?.toString(),
    });
  }

  /**
   * Returns the parameters needed to prepare a transaction mint a token.
   * @param param0.minterAccount The account that will mint the token.
   * @param param0.mintable The mintable token to mint.
   * @param param0.mintArguments The arguments for the mint (mint recipient, comment, mint referral, quantity to mint)
   * @returns
   */
  async makePrepareMintTokenParams({
    ...rest
  }: {
    minterAccount: Address;
    mintable: MintableGetTokenResponse;
    mintArguments: MintArguments;
  }): Promise<SimulateContractParameters> {
    return makePrepareMintTokenParams({
      ...rest,
      apiClient: this.apiClient,
      publicClient: this.publicClient,
    });
  }

  /**
   * Returns the mintFee, sale fee, and total cost of minting x quantities of a token.
   * @param param0.mintable The mintable token to mint.
   * @param param0.quantityToMint The quantity of tokens to mint.
   * @returns
   */
  async getMintCosts({
    mintable,
    quantityToMint,
  }: {
    mintable: Mintable;
    quantityToMint: number | bigint;
  }): Promise<MintCosts> {
    const mintContextType = validateMintableAndGetContextType(mintable);

    if (mintContextType === "zora_create_1155") {
      return await get1155MintCosts({
        mintable,
        publicClient: this.publicClient,
        quantityToMint: BigInt(quantityToMint),
      });
    }
    if (mintContextType === "zora_create") {
      return await get721MintCosts({
        mintable,
        publicClient: this.publicClient,
        quantityToMint: BigInt(quantityToMint),
      });
    }

    throw new MintError(
      `Mintable type ${mintContextType} is currently unsupported.`,
    );
  }
}

/**
 * Creates a new MintClient.
 * @param param0.chain The chain to use for the mint client.
 * @param param0.publicClient Optional viem public client
 * @param param0.httpClient Optional http client to override post, get, and retry methods
 * @returns
 */
export function createMintClient({
  chain,
  publicClient,
  httpClient,
}: {
  chain: Chain;
  publicClient?: PublicClient;
  httpClient?: IHttpClient;
}) {
  return new MintClient(chain, publicClient, httpClient);
}

export type TMintClient = ReturnType<typeof createMintClient>;

function validateMintableAndGetContextType(
  mintable: MintableGetTokenResponse | undefined,
) {
  if (!mintable) {
    throw new MintError("No mintable found");
  }

  if (!mintable.is_active) {
    throw new MintInactiveError("Minting token is inactive");
  }

  if (!mintable.mint_context) {
    throw new MintError("No minting context data from zora API");
  }

  if (
    !["zora_create", "zora_create_1155"].includes(
      mintable.mint_context?.mint_context_type!,
    )
  ) {
    throw new MintError(
      `Mintable type ${mintable.mint_context.mint_context_type} is currently unsupported.`,
    );
  }

  return mintable.mint_context.mint_context_type;
}

async function makePrepareMintTokenParams({
  publicClient,
  mintable,
  apiClient,
  ...rest
}: {
  publicClient: PublicClient;
  minterAccount: Address;
  mintable: MintableGetTokenResponse;
  mintArguments: MintArguments;
  apiClient: MintAPIClient;
}): Promise<SimulateContractParameters> {
  const mintContextType = validateMintableAndGetContextType(mintable);

  const thisPublicClient = publicClient;

  if (mintContextType === "zora_create_1155") {
    return makePrepareMint1155TokenParams({
      apiClient,
      publicClient: thisPublicClient,
      mintable,
      mintContextType,
      ...rest,
    });
  }
  if (mintContextType === "zora_create") {
    return makePrepareMint721TokenParams({
      publicClient: thisPublicClient,
      mintable,
      mintContextType,
      ...rest,
    });
  }

  throw new MintError(
    `Mintable type ${mintContextType} is currently unsupported.`,
  );
}

async function get721MintCosts({
  mintable,
  publicClient,
  quantityToMint,
}: {
  mintable: MintableGetTokenResponse;
  publicClient: PublicClient;
  quantityToMint: bigint;
}): Promise<MintCosts> {
  const address = mintable.collection.address as Address;

  const [_, mintFee] = await publicClient.readContract({
    abi: zora721Abi,
    address,
    functionName: "zoraFeeForAmount",
    args: [BigInt(quantityToMint)],
  });

  const tokenPurchaseCost =
    BigInt(mintable.cost.native_price.raw) * quantityToMint;
  return {
    mintFee,
    tokenPurchaseCost,
    totalCost: mintFee + tokenPurchaseCost,
  };
}

async function makePrepareMint721TokenParams({
  publicClient,
  minterAccount,
  mintable,
  mintContextType,
  mintArguments,
}: {
  publicClient: PublicClient;
  mintable: MintableGetTokenResponse;
  mintContextType: ReturnType<typeof validateMintableAndGetContextType>;
  minterAccount: Address;
  mintArguments: MintArguments;
}): Promise<SimulateContractParameters<typeof zora721Abi, "mintWithRewards">> {
  if (mintContextType !== "zora_create") {
    throw new Error("Minted token type must be for 1155");
  }

  const mintValue = (
    await get721MintCosts({
      mintable,
      publicClient,
      quantityToMint: BigInt(mintArguments.quantityToMint),
    })
  ).totalCost;

  const result = {
    abi: zora721Abi,
    address: mintable.contract_address as Address,
    account: minterAccount,
    functionName: "mintWithRewards",
    value: mintValue,
    args: [
      mintArguments.mintToAddress,
      BigInt(mintArguments.quantityToMint),
      mintArguments.mintComment || "",
      mintArguments.mintReferral || zeroAddress,
    ],
  } satisfies SimulateContractParameters<typeof zora721Abi, "mintWithRewards">;

  return result;
}

async function get1155MintFee({
  collectionAddress,
  publicClient,
}: {
  collectionAddress: Address;
  publicClient: PublicClient;
}) {
  return await publicClient.readContract({
    abi: zoraCreator1155ImplABI,
    functionName: "mintFee",
    address: collectionAddress,
  });
}

export type MintCosts = {
  mintFee: bigint;
  tokenPurchaseCost: bigint;
  totalCost: bigint;
};

export async function get1155MintCosts({
  mintable,
  publicClient,
  quantityToMint,
}: {
  mintable: MintableGetTokenResponse;
  publicClient: PublicClient;
  quantityToMint: bigint;
}): Promise<MintCosts> {
  const address = mintable.collection.address as Address;

  const mintFee = await get1155MintFee({
    collectionAddress: address,
    publicClient,
  });

  const mintFeeForTokens = mintFee * quantityToMint;
  const tokenPurchaseCost =
    BigInt(mintable.cost.native_price.raw) * quantityToMint;

  return {
    mintFee: mintFeeForTokens,
    tokenPurchaseCost,
    totalCost: mintFeeForTokens + tokenPurchaseCost,
  };
}

async function makePrepareMint1155TokenParams({
  apiClient,
  publicClient,
  minterAccount,
  mintable,
  mintContextType,
  mintArguments,
}: {
  apiClient: Pick<MintAPIClient, "getSalesConfigFixedPrice">;
  publicClient: PublicClient;
  mintable: Mintable;
  mintContextType: ReturnType<typeof validateMintableAndGetContextType>;
  minterAccount: Address;
  mintArguments: MintArguments;
}) {
  if (mintContextType !== "zora_create_1155") {
    throw new Error("Minted token type must be for 1155");
  }

  const mintQuantity = BigInt(mintArguments.quantityToMint);

  const address = mintable.collection.address as Address;

  const mintValue = (
    await get1155MintCosts({
      mintable,
      publicClient,
      quantityToMint: mintQuantity,
    })
  ).totalCost;

  const tokenFixedPriceMinter = await apiClient.getSalesConfigFixedPrice({
    contractAddress: address,
    tokenId: BigInt(mintable.token_id!),
  });

  const result = {
    abi: zoraCreator1155ImplABI,
    functionName: "mintWithRewards",
    account: minterAccount,
    value: mintValue,
    address,
    /* args: minter, tokenId, quantity, minterArguments, mintReferral */
    args: [
      (tokenFixedPriceMinter ||
        zoraCreatorFixedPriceSaleStrategyAddress[999]) as Address,
      BigInt(mintable.token_id!),
      mintQuantity,
      encodeAbiParameters(parseAbiParameters("address, string"), [
        mintArguments.mintToAddress,
        mintArguments.mintComment || "",
      ]),
      mintArguments.mintReferral || zeroAddress,
    ],
  } satisfies SimulateContractParameters<
    typeof zoraCreator1155ImplABI,
    "mintWithRewards"
  >;

  return result;
}

export type Mintable = MintableGetTokenResponse;
