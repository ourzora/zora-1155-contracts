import {
  Address,
  TypedDataDomain,
  TypedData,
  TypedDataToPrimitiveTypes,
} from "abitype";
import {
  Hex,
  TypedDataDefinition,
  encodeAbiParameters,
  getAbiItem,
  keccak256,
  toHex,
  parseEther,
} from "viem";
import {
  zoraMints1155Address,
  iPremintDefinitionsABI,
  sponsoredSparksSpenderAddress,
  commentsAddress,
  callerAndCommenterAddress,
} from "./generated/wagmi";
import {
  PremintConfigEncoded,
  PremintConfigV1,
  PremintConfigV2,
  PremintConfigVersion,
  PremintConfigWithVersion,
  TokenConfigWithVersion,
  TokenCreationConfigV1,
  TokenCreationConfigV2,
  TokenCreationConfigV3,
  PermitComment,
  PermitSparkComment,
  PermitMintAndComment,
  PermitBuyOnSecondaryAndComment,
} from "./types";

const premintTypedDataDomain = ({
  chainId,
  version,
  creator1155Contract: verifyingContract,
}: {
  chainId: number;
  version: PremintConfigVersion;
  creator1155Contract: Address;
}): TypedDataDomain => ({
  chainId,
  name: "Preminter",
  version,
  verifyingContract,
});

const premintV1TypedDataType = {
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
} as const satisfies TypedData;

const encodeTokenConfigV1 = (config: TokenCreationConfigV1) => {
  const abiItem = getAbiItem({
    abi: iPremintDefinitionsABI,
    name: "tokenConfigV1Definition",
  });

  return encodeAbiParameters(abiItem.inputs, [config]);
};

const encodeTokenConfigV2 = (config: TokenCreationConfigV2) => {
  const abiItem = getAbiItem({
    abi: iPremintDefinitionsABI,
    name: "tokenConfigV2Definition",
  });

  return encodeAbiParameters(abiItem.inputs, [config]);
};

const encodeTokenConfigV3 = (config: TokenCreationConfigV3) => {
  const abiItem = getAbiItem({
    abi: iPremintDefinitionsABI,
    name: "tokenConfigV3Definition",
  });

  return encodeAbiParameters(abiItem.inputs, [config]);
};

const encodeTokenConfig = <T extends PremintConfigVersion>({
  tokenConfig,
  premintConfigVersion,
}: TokenConfigWithVersion<T>): Hex => {
  if (premintConfigVersion === PremintConfigVersion.V1) {
    return encodeTokenConfigV1(tokenConfig as TokenCreationConfigV1);
  }
  if (premintConfigVersion === PremintConfigVersion.V2) {
    return encodeTokenConfigV2(tokenConfig as TokenCreationConfigV2);
  }
  if (premintConfigVersion === PremintConfigVersion.V3) {
    return encodeTokenConfigV3(tokenConfig as TokenCreationConfigV3);
  }

  throw new Error("Invalid PremintConfigVersion: " + premintConfigVersion);
};

export const encodePremintConfig = <T extends PremintConfigVersion>({
  premintConfig,
  premintConfigVersion,
}: PremintConfigWithVersion<T>): PremintConfigEncoded => {
  const encodedTokenConfig = encodeTokenConfig({
    premintConfigVersion,
    tokenConfig: premintConfig.tokenConfig,
  });

  return {
    deleted: premintConfig.deleted,
    uid: premintConfig.uid,
    version: premintConfig.version,
    premintConfigVersion: keccak256(toHex(premintConfigVersion)),
    tokenConfig: encodedTokenConfig,
  };
};

/**
 * Builds a typed data definition for a PremintConfigV1 to be signed
 * @returns
 */
export const premintV1TypedDataDefinition = ({
  chainId,
  creator1155Contract,
  message,
}: {
  chainId: number;
  creator1155Contract: Address;
  message: PremintConfigV1;
}): TypedDataDefinition<
  typeof premintV1TypedDataType,
  "CreatorAttribution"
> => ({
  types: premintV1TypedDataType,
  primaryType: "CreatorAttribution",
  domain: premintTypedDataDomain({
    chainId,
    version: PremintConfigVersion.V1,
    creator1155Contract,
  }),
  message,
});

const premintV2TypedDataType = {
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
} as const satisfies TypedData;

/**
 * Builds a typed data definition for a PremintConfigV2 to be signed
 */
export const premintV2TypedDataDefinition = ({
  chainId,
  creator1155Contract,
  message,
}: {
  chainId: number;
  creator1155Contract: Address;
  message: PremintConfigV2;
}): TypedDataDefinition<
  typeof premintV2TypedDataType,
  "CreatorAttribution"
> => ({
  types: premintV2TypedDataType,
  primaryType: "CreatorAttribution",
  domain: premintTypedDataDomain({
    chainId,
    version: PremintConfigVersion.V2,
    creator1155Contract,
  }),
  message,
});

export type PremintTypeDataDefinitionParams<T extends PremintConfigVersion> = {
  verifyingContract: Address;
  chainId: number;
} & PremintConfigWithVersion<T>;

/**
 * Creates a typed data definition for a premint config.  Works for all versions of the premint config by specifying the premintConfigVersion.
 *
 * @param params.verifyingContract the address of the 1155 contract
 * @param params.chainId the chain id the premint is signed for
 * @param params.premintConfigVersion the version of the premint config
 * @param params.premintConfig the premint config
 * @returns
 */
export const premintTypedDataDefinition = <T extends PremintConfigVersion>({
  verifyingContract,
  chainId,
  premintConfigVersion: version,
  premintConfig,
}: PremintTypeDataDefinitionParams<T>): TypedDataDefinition => {
  if (version === PremintConfigVersion.V1)
    return premintV1TypedDataDefinition({
      chainId,
      creator1155Contract: verifyingContract,
      message: premintConfig as PremintConfigV1,
    });
  if (version === PremintConfigVersion.V2) {
    return premintV2TypedDataDefinition({
      chainId,
      creator1155Contract: verifyingContract,
      message: premintConfig as PremintConfigV2,
    });
  }

  throw new Error(`Invalid version ${version}`);
};

const permitSafeTransferTypedDataType = {
  PermitSafeTransfer: [
    { name: "owner", type: "address" },
    { name: "to", type: "address" },
    { name: "tokenId", type: "uint256" },
    { name: "quantity", type: "uint256" },
    { name: "safeTransferData", type: "bytes" },
    { name: "nonce", type: "uint256" },
    { name: "deadline", type: "uint256" },
  ],
} as const;

/**
 * Builds a typed data definition for a PermitSafeTransfer on the Mints1155 contract to be signed
 */
export const mintsSafeTransferTypedDataDefinition = ({
  chainId,
  message,
}: {
  chainId: keyof typeof zoraMints1155Address;
  message: TypedDataToPrimitiveTypes<
    typeof permitSafeTransferTypedDataType
  >["PermitSafeTransfer"];
}): TypedDataDefinition<
  typeof permitSafeTransferTypedDataType,
  "PermitSafeTransfer"
> => ({
  types: permitSafeTransferTypedDataType,
  message,
  primaryType: "PermitSafeTransfer",
  domain: {
    chainId,
    name: "Mints",
    version: "1",
    verifyingContract: zoraMints1155Address[chainId],
  },
});

const permitSafeBatchTransferTypedDataType = {
  Permit: [
    {
      name: "owner",
      type: "address",
    },
    {
      name: "to",
      type: "address",
    },
    {
      name: "tokenIds",
      type: "uint256[]",
    },
    {
      name: "quantities",
      type: "uint256[]",
    },
    {
      name: "safeTransferData",
      type: "bytes",
    },
    {
      name: "nonce",
      type: "uint256",
    },
    {
      name: "deadline",
      type: "uint256",
    },
  ],
} as const;

/**
 * Builds a typed data definition for a PermitSafeTransferBatch on the Mints1155 contract to be signed
 * @returns
 */
export const mintsSafeTransferBatchTypedDataDefinition = ({
  chainId,
  message,
}: {
  chainId: keyof typeof zoraMints1155Address;
  message: TypedDataToPrimitiveTypes<
    typeof permitSafeBatchTransferTypedDataType
  >["Permit"];
}): TypedDataDefinition<
  typeof permitSafeBatchTransferTypedDataType,
  "Permit"
> => ({
  types: permitSafeBatchTransferTypedDataType,
  message,
  primaryType: "Permit",
  domain: {
    chainId,
    name: "Mints",
    version: "1",
    verifyingContract: zoraMints1155Address[chainId],
  },
});

export const sponsoredSparksBatchTransferTypedDataType = {
  SponsoredMintBatch: [
    {
      name: "verifier",
      type: "address",
    },
    {
      name: "from",
      type: "address",
    },
    {
      name: "destination",
      type: "address",
    },
    {
      name: "data",
      type: "bytes",
    },
    {
      name: "expectedRedeemAmount",
      type: "uint256",
    },
    {
      name: "totalAmount",
      type: "uint256",
    },
    {
      name: "ids",
      type: "uint256[]",
    },
    {
      name: "quantities",
      type: "uint256[]",
    },
    {
      name: "nonce",
      type: "uint256",
    },
    {
      name: "deadline",
      type: "uint256",
    },
  ],
} as const;

/**
 * Builds a typed data definition for a PermitSafeTransferBatch on the Mints1155 contract to be signed
 * @returns
 */
export const sponsoredSparksBatchTypedDataDefinition = ({
  chainId,
  message,
}: {
  chainId: keyof typeof sponsoredSparksSpenderAddress;
  message: TypedDataToPrimitiveTypes<
    typeof sponsoredSparksBatchTransferTypedDataType
  >["SponsoredMintBatch"];
}): TypedDataDefinition<
  typeof sponsoredSparksBatchTransferTypedDataType,
  "SponsoredMintBatch"
> => ({
  types: sponsoredSparksBatchTransferTypedDataType,
  message,
  primaryType: "SponsoredMintBatch",
  domain: {
    chainId,
    name: "SponsoredSparksSpender",
    version: "1",
    verifyingContract: sponsoredSparksSpenderAddress[chainId],
  },
});

const commentIdentifierType = [
  { name: "contractAddress", type: "address" },
  { name: "tokenId", type: "uint256" },
  { name: "commenter", type: "address" },
  { name: "nonce", type: "bytes32" },
] as const;

const commentsDomain = ({
  signingChainId,
  destinationChainId,
}: {
  signingChainId: number;
  destinationChainId: keyof typeof commentsAddress;
}): TypedDataDomain => ({
  chainId: signingChainId,
  name: "Comments",
  version: "1",
  verifyingContract: commentsAddress[destinationChainId]!,
});

/**
 * Generates the typed data definition for a permit comment, for cross-chain commenting.
 *
 * The permit allows a user to sign a comment message on one chain, which can then be
 * submitted by anyone on the destination chain to execute the comment action.
 *
 * The permit includes details such as the comment text, the commenter's address,
 * the comment being replied to, and chain IDs for the source and destination chains.
 *
 * The typed data is generated in a way that makes the signature happen on the source chain
 * but be valid to be executed on the destination chain.
 *
 * @param message - The {@link PermitComment} containing the details of the comment permit.
 * @param signingAccount - (optional) The account that is signing the message, if different thatn the commentor.
 * Only needed if the commentor is a smart wallet; in this case the signing account should be an account
 * that is one of the smart wallet owners.
 * @returns A {@link TypedDataDefinition} object compatible with EIP-712 for structured data hashing and signing,
 * including types, message, primary type, domain, and the signer's account address, which is
 * the commenter's address.
 */
export const permitCommentTypedDataDefinition = (
  message: PermitComment,
  signingAccount?: Address,
): TypedDataDefinition<typeof permitCommentTypedDataType, "PermitComment"> & {
  account: Address;
} => {
  const permitCommentTypedDataType = {
    PermitComment: [
      { name: "contractAddress", type: "address" },
      { name: "tokenId", type: "uint256" },
      { name: "commenter", type: "address" },
      { name: "replyTo", type: "CommentIdentifier" },
      { name: "text", type: "string" },
      { name: "deadline", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "commenterSmartWallet", type: "address" },
      { name: "referrer", type: "address" },
      { name: "sourceChainId", type: "uint32" },
      { name: "destinationChainId", type: "uint32" },
    ],
    CommentIdentifier: commentIdentifierType,
  } as const;
  return {
    types: permitCommentTypedDataType,
    message,
    primaryType: "PermitComment",
    domain: commentsDomain({
      signingChainId: message.sourceChainId,
      destinationChainId:
        message.destinationChainId as keyof typeof commentsAddress,
    }),
    account: signingAccount || message.commenter,
  };
};

/**
 * Generates the typed data definition for a permit spark comment, for cross-chain sparking (liking with value) of comments.
 *
 * The permit allows a user to sign a spark comment message on one chain, which can then be
 * submitted by anyone on the destination chain to execute the spark action.
 *
 * The permit includes details such as the comment to be sparked, the sparker's address,
 * the quantity of sparks, and the source and destination chain ids.
 *
 * The typed data is generated in a way that makes the signature happen on the source chain
 * but be valid to be executed on the destination chain.
 *
 * @param message - The {@link PermitSparkComment} containing the details of the spark comment permit.
 * @param signingAccount - (optional) The account that is signing the message, if different than the commenter.
 * Only needed if the commenter is a smart wallet; in this case the signing account should be an account
 * that is one of the smart wallet owners.
 * @returns A {@link TypedDataDefinition} object compatible with EIP-712 for structured data hashing and signing,
 * including types, message, primary type, domain, and the signer's account address, which is
 * the sparker's address.
 */
export const permitSparkCommentTypedDataDefinition = (
  message: PermitSparkComment,
  signingAccount?: Address,
): TypedDataDefinition<
  typeof permitSparkCommentTypedDataType,
  "PermitSparkComment"
> & { account: Address } => {
  const permitSparkCommentTypedDataType = {
    PermitSparkComment: [
      { name: "comment", type: "CommentIdentifier" },
      { name: "sparker", type: "address" },
      { name: "sparksQuantity", type: "uint256" },
      { name: "deadline", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "referrer", type: "address" },
      { name: "sourceChainId", type: "uint32" },
      { name: "destinationChainId", type: "uint32" },
    ],
    CommentIdentifier: commentIdentifierType,
  } as const;

  return {
    types: permitSparkCommentTypedDataType,
    message,
    primaryType: "PermitSparkComment",
    domain: commentsDomain({
      signingChainId: message.sourceChainId,
      destinationChainId:
        message.destinationChainId as keyof typeof commentsAddress,
    }),
    account: signingAccount || message.sparker,
  };
};

/**
 * Returns the minimum value required for a spark transaction (0.000001 ETH)
 * This small amount is used to prevent spam and cover basic gas costs
 * @returns The minimum spark value in wei (1e12 wei or 0.000001 ETH)
 */
export const sparkValue = () => parseEther("0.000001");

/**
 * Generates the typed data definition for a permit timed sale mint and comment operation.
 *
 * This function creates a structured data object that can be used for EIP-712 signing,
 * allowing users to sign a message on one chain that permits a timed sale mint and comment
 * action to be executed on another chain.
 *
 * @param message - The {@link PermitMintAndComment} containing the details of the permit.
 * @param signingAccount - (optional) The account that is signing the message, if different from the commenter.
 * This is typically used when the commenter is a smart wallet, and the signing account is one of its owners.
 * @returns A {@link TypedDataDefinition} object compatible with EIP-712 for structured data hashing and signing,
 * including types, message, primary type, domain, and the signer's account address.
 */
export const permitMintAndCommentTypedDataDefinition = (
  message: PermitMintAndComment,
  signingAccount?: Address,
): TypedDataDefinition<
  typeof permitTimedSaleMintAndCommentTypedDataType,
  "PermitTimedSaleMintAndComment"
> & { account: Address } => {
  const permitTimedSaleMintAndCommentTypedDataType = {
    PermitTimedSaleMintAndComment: [
      { name: "commenter", type: "address" },
      { name: "quantity", type: "uint256" },
      { name: "collection", type: "address" },
      { name: "tokenId", type: "uint256" },
      { name: "mintReferral", type: "address" },
      { name: "comment", type: "string" },
      { name: "deadline", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "sourceChainId", type: "uint32" },
      { name: "destinationChainId", type: "uint32" },
    ],
  } as const;

  const callerAndCommenterDomain = ({
    signingChainId,
    destinationChainId,
  }: {
    signingChainId: number;
    destinationChainId: keyof typeof callerAndCommenterAddress;
  }) => ({
    name: "CallerAndCommenter",
    version: "1",
    chainId: signingChainId,
    verifyingContract: callerAndCommenterAddress[destinationChainId],
  });

  return {
    types: permitTimedSaleMintAndCommentTypedDataType,
    message,
    primaryType: "PermitTimedSaleMintAndComment",
    domain: callerAndCommenterDomain({
      signingChainId: message.sourceChainId,
      destinationChainId:
        message.destinationChainId as keyof typeof callerAndCommenterAddress,
    }),
    account: signingAccount || message.commenter,
  };
};

/**
 * Generates the typed data definition for a permit buy on secondary and comment operation.
 *
 * This function creates a structured data object that can be used for EIP-712 signing,
 * allowing users to sign a message on one chain that permits a buy on secondary market and comment
 * action to be executed on another chain.
 *
 * @param message - The {@link PermitBuyOnSecondaryAndComment} containing the details of the permit.
 * @param signingAccount - (optional) The account that is signing the message, if different from the commenter.
 * This is typically used when the commenter is a smart wallet, and the signing account is one of its owners.
 * @returns A {@link TypedDataDefinition} object compatible with EIP-712 for structured data hashing and signing,
 * including types, message, primary type, domain, and the signer's account address.
 */
export const permitBuyOnSecondaryAndCommentTypedDataDefinition = (
  message: PermitBuyOnSecondaryAndComment,
  signingAccount?: Address,
): TypedDataDefinition<
  typeof permitBuyOnSecondaryAndCommentTypedDataType,
  "PermitBuyOnSecondaryAndComment"
> & { account: Address } => {
  const permitBuyOnSecondaryAndCommentTypedDataType = {
    PermitBuyOnSecondaryAndComment: [
      { name: "commenter", type: "address" },
      { name: "quantity", type: "uint256" },
      { name: "collection", type: "address" },
      { name: "tokenId", type: "uint256" },
      { name: "maxEthToSpend", type: "uint256" },
      { name: "sqrtPriceLimitX96", type: "uint160" },
      { name: "comment", type: "string" },
      { name: "deadline", type: "uint256" },
      { name: "nonce", type: "bytes32" },
      { name: "sourceChainId", type: "uint32" },
      { name: "destinationChainId", type: "uint32" },
    ],
  } as const;

  const callerAndCommenterDomain = ({
    signingChainId,
    destinationChainId,
  }: {
    signingChainId: number;
    destinationChainId: keyof typeof callerAndCommenterAddress;
  }) => ({
    name: "CallerAndCommenter",
    version: "1",
    chainId: signingChainId,
    verifyingContract: callerAndCommenterAddress[destinationChainId],
  });

  return {
    types: permitBuyOnSecondaryAndCommentTypedDataType,
    message,
    primaryType: "PermitBuyOnSecondaryAndComment",
    domain: callerAndCommenterDomain({
      signingChainId: message.sourceChainId,
      destinationChainId:
        message.destinationChainId as keyof typeof callerAndCommenterAddress,
    }),
    account: signingAccount || message.commenter,
  };
};
