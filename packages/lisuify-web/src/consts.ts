export const pageTitle = "LiSuify";

export const pageDescription = "Stake SUI for the best profit";

export const githubLink = "https://github.com/lisuify/lisuify";

export const network: "mainnet" | "testnet" | "devnet" | "localnet" =
  import.meta.env.PUBLIC_NETWORK;

export const suiDecimal = 9;

export const originalLisuifyId = import.meta.env.PUBLIC_ORIGINAL_LISUIFY_ID;

export const lisuifyId = import.meta.env.PUBLIC_LISUIFY_ID;

export const stakePoolId = import.meta.env.PUBLIC_STAKE_POOL_ID;

export const MENU = {
  "Getting Started": [
    "/docs/getting-started/what-is-lisuify",
    "/docs/getting-started/what-is-lisui",
    "/docs/getting-started/faq",
  ],
  LiSuify: ["/docs/lisuify/introduction", "/docs/lisuify/liquid-staking"],
};
