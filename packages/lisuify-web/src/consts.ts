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
    "/docs/getting-started/faq",
  ],
  LiSuify: ["/docs/lisuify/introduction", "/docs/lisuify/liquid-staking"],
};

export const NAVIGATION_MENU = {
  "Getting Started": {
    "What is LiSuify?": "/docs/getting-started/what-is-lisuify",
    FAQ: "/docs/getting-started/faq",
  },
  Documents: {
    Introduction: "/docs/lisuify/introduction",
    "Liquid Staking": "/docs/lisuify/liquid-staking",
  },
};
