import { Address } from "abitype";
import { ExtractAbiFunction, AbiParametersToPrimitiveTypes } from "abitype";
import {
  zoraCreator1155PremintExecutorImplABI as preminterAbi,
  zoraCreator1155ImplABI,
  zoraCreator1155PremintExecutorImplABI,
  zoraCreator1155PremintExecutorImplAddress,
} from "@zoralabs/protocol-deployments";
import {
  TypedDataDefinition,
  recoverTypedDataAddress,
  Hex,
  PublicClient,
  zeroAddress,
  hashDomain,
  keccak256,
  concat,
  recoverAddress,
  GetEventArgs,
} from "viem";

type PremintV1Inputs = ExtractAbiFunction<
  typeof preminterAbi,
  "premintV1"
>["inputs"];

type PremintV1HashDataTypes = AbiParametersToPrimitiveTypes<PremintV1Inputs>;

export type ContractCreationConfig = PremintV1HashDataTypes[0];

export type PremintConfigV1 = PremintV1HashDataTypes[1];
export type TokenCreationConfigV1 = PremintConfigV1["tokenConfig"];

export type MintArguments = PremintV1HashDataTypes[4];

type PremintV2Inputs = ExtractAbiFunction<
  typeof preminterAbi,
  "premintV2"
>["inputs"];

type PremintV2HashDataTypes = AbiParametersToPrimitiveTypes<PremintV2Inputs>;

export type PremintConfigV2 = PremintV2HashDataTypes[1];
export type TokenCreationConfigV2 = PremintConfigV2["tokenConfig"];

const v1Types = {
  CreatorAttribution: [
    { name: "tokenConfig", type: "TokenCreationConfig" },
    // unique id scoped to the contract and token to create.
    // ensure that a signature can be replaced, as long as the replacement
    // has the same uid, and a newer version.
    { name: "uid", type: "uint32" },
    { name: "version", type: "uint32" },
    // if this update should result in the signature being deleted.
    { name: "deleted", type: "bool" },
  ],
  TokenCreationConfig: [
    { name: "tokenURI", type: "string" },
    { name: "maxSupply", type: "uint256" },
    { name: "maxTokensPerAddress", type: "uint64" },
    { name: "pricePerToken", type: "uint96" },
    { name: "mintStart", type: "uint64" },
    { name: "mintDuration", type: "uint64" },
    { name: "royaltyMintSchedule", type: "uint32" },
    { name: "royaltyBPS", type: "uint32" },
    { name: "royaltyRecipient", type: "address" },
    { name: "fixedPriceMinter", type: "address" },
  ],
} as const;

const v2Types = {
  CreatorAttribution: [
    { name: "tokenConfig", type: "TokenCreationConfig" },
    // unique id scoped to the contract and token to create.
    // ensure that a signature can be replaced, as long as the replacement
    // has the same uid, and a newer version.
    { name: "uid", type: "uint32" },
    { name: "version", type: "uint32" },
    // if this update should result in the signature being deleted.
    { name: "deleted", type: "bool" },
  ],
  TokenCreationConfig: [
    { name: "tokenURI", type: "string" },
    { name: "maxSupply", type: "uint256" },
    { name: "maxTokensPerAddress", type: "uint64" },
    { name: "pricePerToken", type: "uint96" },
    { name: "mintStart", type: "uint64" },
    { name: "mintDuration", type: "uint64" },
    { name: "royaltyBPS", type: "uint32" },
    { name: "payoutRecipient", type: "address" },
    { name: "fixedPriceMinter", type: "address" },
    { name: "createReferral", type: "address" },
  ],
} as const;

export const PreminterDomain = "Preminter";

type PremintConfigVersion = "1" | "2";

export const PremintConfigVersion = {
  V1: "1",
  V2: "2",
} as const;

type PremintConfigForVersion<T extends PremintConfigVersion> = T extends "1"
  ? PremintConfigV1
  : PremintConfigV2;

type PremintConfigWithVersion<T extends PremintConfigVersion> = {
  premintConfig: PremintConfigForVersion<T>;
  premintConfigVersion: T;
};

export type PremintConfigAndVersion =
  | PremintConfigWithVersion<"1">
  | PremintConfigWithVersion<"2">;

export const getPremintExecutorAddress = () =>
  zoraCreator1155PremintExecutorImplAddress[999];

/**
 * Creates a typed data definition for a premint config.  Works for all versions of the premint config by specifying the premintConfigVersion.
 *
 * @param params.verifyingContract the address of the 1155 contract
 * @param params.chainId the chain id the premint is signed for
 * @param params.premintConfigVersion the version of the premint config
 * @param params.premintConfig the premint config
 * @returns
 */
export const premintTypedDataDefinition = ({
  verifyingContract,
  chainId,
  premintConfigVersion: version,
  premintConfig,
}: {
  verifyingContract: Address;
  chainId: number;
} & PremintConfigAndVersion): TypedDataDefinition => {
  const domain = {
    chainId,
    name: PreminterDomain,
    version,
    verifyingContract: verifyingContract,
  };

  if (version === PremintConfigVersion.V1)
    return {
      domain,
      types: v1Types,
      message: premintConfig,
      primaryType: "CreatorAttribution",
    } satisfies TypedDataDefinition<typeof v1Types, "CreatorAttribution">;
  if (version === PremintConfigVersion.V2) {
    return {
      domain,
      types: v2Types,
      message: premintConfig,
      primaryType: "CreatorAttribution",
    } satisfies TypedDataDefinition<typeof v2Types, "CreatorAttribution">;
  }

  throw new Error(`Invalid version ${version}`);
};

export type IsValidSignatureReturn = {
  isAuthorized: boolean;
  recoveredAddress?: Address;
};

export async function isAuthorizedToCreatePremint({
  collection,
  collectionAddress,
  publicClient,
  premintConfig,
  premintConfigVersion,
  signature,
  signer,
}: {
  collection: ContractCreationConfig;
  collectionAddress: Address;
  publicClient: PublicClient;
  signature: Hex;
  signer: Address;
} & PremintConfigAndVersion) {
  // if we are using legacy version of premint config, we can use the function
  // "isValidSignature" which we know exists on the premint executor contract
  if (premintConfigVersion === PremintConfigVersion.V1) {
    const [isValidSignature] = await publicClient.readContract({
      abi: zoraCreator1155PremintExecutorImplABI,
      address: getPremintExecutorAddress(),
      functionName: "isValidSignature",
      args: [collection, premintConfig, signature],
    });

    return isValidSignature;
  }

  // otherwize, we must assume the newer version of premint executor is deployed, so we call that.
  return await publicClient.readContract({
    abi: preminterAbi,
    address: getPremintExecutorAddress(),
    functionName: "isAuthorizedToCreatePremint",
    args: [signer, collection.contractAdmin, collectionAddress],
  });
}

export async function recoverPremintSigner({
  signature,
  ...rest
}: {
  signature: Hex;
  chainId: number;
  verifyingContract: Address;
} & PremintConfigAndVersion): Promise<Address> {
  const typedData = premintTypedDataDefinition(rest);
  return await recoverTypedDataAddress({
    ...typedData,
    signature,
  });
}

export async function tryRecoverPremintSigner(
  params: Parameters<typeof recoverPremintSigner>[0],
) {
  try {
    return await recoverPremintSigner(params);
  } catch (error) {
    console.error(error);
    return undefined;
  }
}

/**
 * Recovers the address from a typed data signature and then checks if the recovered address is authorized to create a premint
 *
 * @param params validationProperties
 * @param params.typedData typed data definition for premint config
 * @param params.signature signature to validate
 * @param params.publicClient public rpc read-only client
 * @param params.premintConfigContractAdmin the original contractAdmin on the ContractCreationConfig for the premint; this is usually the original creator of the premint
 * @param params.tokenContract the address of the 1155 contract
 * @returns
 */
export async function isValidSignature({
  signature,
  publicClient,
  collection,
  chainId,
  ...premintConfigAndVersion
}: {
  collection: ContractCreationConfig;
  signature: Hex;
  chainId: number;
  publicClient: PublicClient;
} & PremintConfigAndVersion): Promise<IsValidSignatureReturn> {
  const tokenContract = await getPremintCollectionAddress({
    collection,
    publicClient,
  });
  const recoveredAddress = await tryRecoverPremintSigner({
    ...premintConfigAndVersion,
    signature,
    verifyingContract: tokenContract,
    chainId,
  });

  if (!recoverAddress) {
    return {
      isAuthorized: false,
    };
  }

  const isAuthorized = await isAuthorizedToCreatePremint({
    signer: recoveredAddress!,
    collection,
    collectionAddress: tokenContract,
    publicClient,
    signature,
    ...premintConfigAndVersion,
  });

  return {
    isAuthorized,
    recoveredAddress,
  };
}

/**
 * Converts a premint config from v1 to v2
 *
 * @param premintConfig premint config to convert
 * @param createReferral address that referred the creator, that will receive create referral rewards for the created token
 */
export function migratePremintConfigToV2({
  premintConfig,
  createReferral = zeroAddress,
}: {
  premintConfig: PremintConfigV1;
  createReferral: Address;
}): PremintConfigV2 {
  return {
    ...premintConfig,
    tokenConfig: {
      tokenURI: premintConfig.tokenConfig.tokenURI,
      maxSupply: premintConfig.tokenConfig.maxSupply,
      maxTokensPerAddress: premintConfig.tokenConfig.maxTokensPerAddress,
      pricePerToken: premintConfig.tokenConfig.pricePerToken,
      mintStart: premintConfig.tokenConfig.mintStart,
      mintDuration: premintConfig.tokenConfig.mintDuration,
      payoutRecipient: premintConfig.tokenConfig.royaltyRecipient,
      royaltyBPS: premintConfig.tokenConfig.royaltyBPS,
      fixedPriceMinter: premintConfig.tokenConfig.fixedPriceMinter,
      createReferral,
    },
  };
}

export type CreatorAttributionEventParams = GetEventArgs<
  typeof zoraCreator1155ImplABI,
  "CreatorAttribution",
  { EnableUnion: false }
>;

/**
 * Recovers the address from a CreatorAttribution event emitted from a ZoraCreator1155 contract
 * Useful for verifying that the creator of a token is the one who signed a premint for its creation.
 * 

 * @param creatorAttribution parameters from the CreatorAttribution event
 * @param chainId the chain id of the current chain
 * @param tokenContract the address of the 1155 contract
 * @returns the address of the signer
 */
export const recoverCreatorFromCreatorAttribution = async ({
  creatorAttribution: { version, domainName, structHash, signature },
  chainId,
  tokenContract,
}: {
  creatorAttribution: CreatorAttributionEventParams;
  tokenContract: Address;
  chainId: number;
}) => {
  // hash the eip712 domain based on the parameters emitted from the event:
  const hashedDomain = hashDomain({
    domain: {
      chainId,
      name: domainName,
      verifyingContract: tokenContract,
      version,
    },
    types: {
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        {
          name: "chainId",
          type: "uint256",
        },
        {
          name: "verifyingContract",
          type: "address",
        },
      ],
    },
  });

  // re-build the eip-712 typed data hash, consisting of the hashed domain and the structHash emitted from the event:
  const parts: Hex[] = ["0x1901", hashedDomain, structHash!];

  const hashedTypedData = keccak256(concat(parts));

  return await recoverAddress({
    hash: hashedTypedData,
    signature: signature!,
  });
};

/**
 * Checks if the 1155 contract at that address supports the given version of the premint config.
 */
export const supportsPremintVersion = async (
  version: PremintConfigVersion,
  tokenContract: Address,
  publicClient: PublicClient,
): Promise<boolean> => {
  const supportedPremintSignatureVersions = await publicClient.readContract({
    abi: preminterAbi,
    address: getPremintExecutorAddress(),
    functionName: "supportedPremintSignatureVersions",
    args: [tokenContract],
  });

  return supportedPremintSignatureVersions.includes(version);
};

export async function getPremintCollectionAddress({
  collection,
  publicClient,
}: {
  collection: ContractCreationConfig;
  publicClient: PublicClient;
}): Promise<Address> {
  return publicClient.readContract({
    address: getPremintExecutorAddress(),
    abi: zoraCreator1155PremintExecutorImplABI,
    functionName: "getContractAddress",
    args: [collection],
  });
}
