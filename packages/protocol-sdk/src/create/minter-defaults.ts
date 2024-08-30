import { Concrete } from "src/utils";
import {
  SalesConfigParamsType,
  AllowListParamType,
  Erc20ParamsType,
  FixedPriceParamsType,
  SaleStartAndEnd,
  MaxTokensPerAddress,
  ConcreteSalesConfig,
  TimedSaleParamsType,
} from "./types";

// 200 mints worth of eth
export const DEFAULT_MINIMUM_MARKET_ETH = 2220000000000000n;

// 24 hour countdown
export const DEFAULT_MARKET_COUNTDOWN = BigInt(24 * 60 * 60);

// Sales end forever amount (uint64 max)
export const SALE_END_FOREVER = 18446744073709551615n;

const DEFAULT_SALE_START_AND_END: Concrete<SaleStartAndEnd> = {
  // Sale start time – defaults to beginning of unix time
  saleStart: 0n,
  // This is the end of uint64, plenty of time
  saleEnd: SALE_END_FOREVER,
};

const DEFAULT_MAX_TOKENS_PER_ADDRESS: Concrete<MaxTokensPerAddress> = {
  maxTokensPerAddress: 0n,
};

const erc20SaleSettingsWithDefaults = (
  params: Erc20ParamsType,
): Concrete<Erc20ParamsType> => ({
  ...DEFAULT_SALE_START_AND_END,
  ...DEFAULT_MAX_TOKENS_PER_ADDRESS,
  ...params,
});

const allowListWithDefaults = (
  allowlist: AllowListParamType,
): Concrete<AllowListParamType> => {
  return {
    ...DEFAULT_SALE_START_AND_END,
    ...allowlist,
  };
};

const fixedPriceSettingsWithDefaults = (
  params: FixedPriceParamsType,
): Concrete<FixedPriceParamsType> => ({
  ...DEFAULT_SALE_START_AND_END,
  ...DEFAULT_MAX_TOKENS_PER_ADDRESS,
  type: "fixedPrice",
  ...params,
});

export const parseNameIntoSymbol = (name: string) => {
  if (name === "") {
    throw new Error("Name must be provided to generate a symbol");
  }
  const result =
    "$" +
    name
      // Remove all non-alphanumeric characters
      .replace(/[^a-zA-Z0-9]/g, "")
      // and leading dollar signs
      .replace(/^\$+/, "")
      .toUpperCase()
      // Remove all vowels and spaces
      .replace(/[AEIOU\s]/g, "")
      // Strip down to 4 characters
      .slice(0, 4);

  if (result === "$") {
    throw new Error("Not enough valid characters to generate a symbol");
  }

  return result;
};

const timedSaleSettingsWithDefaults = (
  params: TimedSaleParamsType,
  contractName: string,
): Concrete<TimedSaleParamsType> => {
  // If the name is not provided, try to fetch it from the metadata
  const erc20Name = params.erc20Name || contractName;
  const symbol = params.erc20Symbol || parseNameIntoSymbol(erc20Name);
  const start = params.saleStart || 0n;
  const countdown = params.marketCountdown || DEFAULT_MARKET_COUNTDOWN;
  const minimumEth = params.minimumMarketEth || DEFAULT_MINIMUM_MARKET_ETH;

  return {
    type: "timed",
    erc20Name: erc20Name,
    erc20Symbol: symbol,
    saleStart: start,
    marketCountdown: countdown,
    minimumMarketEth: minimumEth,
  };
};

const isAllowList = (
  salesConfig: SalesConfigParamsType,
): salesConfig is AllowListParamType => salesConfig.type === "allowlistMint";
const isErc20 = (
  salesConfig: SalesConfigParamsType,
): salesConfig is Erc20ParamsType => salesConfig.type === "erc20Mint";
const isFixedPrice = (
  salesConfig: SalesConfigParamsType,
): salesConfig is FixedPriceParamsType => {
  return (
    salesConfig.type === "fixedPrice" ||
    (salesConfig as FixedPriceParamsType).pricePerToken > 0n
  );
};

export const getSalesConfigWithDefaults = (
  salesConfig: SalesConfigParamsType | undefined,
  contractName: string,
): ConcreteSalesConfig => {
  if (!salesConfig) return timedSaleSettingsWithDefaults({}, contractName);
  if (isAllowList(salesConfig)) {
    return allowListWithDefaults(salesConfig);
  }
  if (isErc20(salesConfig)) {
    return erc20SaleSettingsWithDefaults(salesConfig);
  }
  if (isFixedPrice(salesConfig)) {
    return fixedPriceSettingsWithDefaults(salesConfig);
  }

  return timedSaleSettingsWithDefaults(salesConfig, contractName);
};