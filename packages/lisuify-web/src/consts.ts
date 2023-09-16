export const pageTitle = "LiSuify";

export const pageDescription = "Stake SUI for the best profit";

export const githubLink = "https://github.com/lisuify/lisuify";

export const network: "mainnet" | "testnet" | "devnet" | "localnet" =
  import.meta.env.PUBLIC_NETWORK;

export const originalLisuifyId = import.meta.env.PUBLIC_ORIGINAL_LISUIFY_ID;

export const lisuifyId = import.meta.env.PUBLIC_LISUIFY_ID;

export const stakePoolId = import.meta.env.PUBLIC_STAKE_POOL_ID;

export const SIDE_MENU = {
  "Getting Started": [
    "/docs/getting-started/what-is-lisuify",
    "/docs/getting-started/liquid-staking",
    // "/docs/getting-started/faq",
  ],
  LiSuify: ["/docs/lisuify/whitepaper", "/docs/lisuify/api-reference"],
};

export const NAVIGATION_MENU = {
  "Getting Started": {
    "What is LiSuify?": "/docs/getting-started/what-is-lisuify",
    "Liquid Staking": "/docs/getting-started/liquid-staking",
    // FAQ: "/docs/getting-started/faq",
  },
  Documents: {
    Whitepaper: "/docs/lisuify/whitepaper",
    "API Reference": "/docs/lisuify/api-reference",
  },
};
