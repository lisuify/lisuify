/// <reference types="astro/client" />

interface ImportMetaEnv {
  readonly PUBLIC_NETWORK: "mainnet" | "testnet" | "devnet" | "localnet";
  readonly PUBLIC_ORIGINAL_LISUIFY_ID: string;
  readonly PUBLIC_LISUIFY_ID: string;
  readonly PUBLIC_STAKE_POOL_ID: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
