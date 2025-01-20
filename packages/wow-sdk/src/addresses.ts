import { base, baseSepolia, mainnet } from "viem/chains";

export const addresses = {
  [base.id]: {
    WowFactory: "0x997020E5F59cCB79C74D527Be492Cc610CB9fA2B",
    WowFactoryImpl: "0xeC7136a7F7A699659E1666ECc0F65956aCd35B4C",
    Wow: "0xcfC2dE7f39a9e1460dd282071a458e02372E1F67",
    BondingCurve: "0x91C1863eD54809c45b53bb6090eb437036c792C4",
    NonfungiblePositionManager: "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1",
    SwapRouter02: "0x2626664c2603336E57B271c5C0b26F421741e481",
    WETH: "0x4200000000000000000000000000000000000006",
    UniswapQuoter: "0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a",
  },
  [baseSepolia.id]: {
    WowFactory: "0x04870e22fa217Cb16aa00501D7D5253B8838C1eA",
    WowFactoryImpl: "0x3d92B432362b6C118A6648a6ECe1C4bD436be14e",
    Wow: "0xc81AD785F60CAC8f99D87d1D097AA87b11C0e9E4",
    BondingCurve: "0x31eb0D332F0C13836CCEC763989915d0195AE494",
    NonfungiblePositionManager: "0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2",
    SwapRouter02: "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4",
    WETH: "0x4200000000000000000000000000000000000006",
    UniswapQuoter: "0xC5290058841028F1614F3A6F0F5816cAd0df5E27",
  },
  [mainnet.id]: {
    WETH: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    UniswapQuoter: "0x61fFE014bA17989E743c5F6cB21bF9697530B21e",
  },
};