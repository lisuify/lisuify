/// <reference path="../.astro/types.d.ts" />
/// <reference types="astro/client" />
import type { DirectoryRuntime } from "@astrojs/cloudflare";
import type { KVNamespace } from "@cloudflare/workers-types";

interface ImportMetaEnv {
  readonly PUBLIC_NETWORK: "mainnet" | "testnet" | "devnet" | "localnet";
  readonly PUBLIC_ORIGINAL_LISUIFY_ID: string;
  readonly PUBLIC_LISUIFY_ID: string;
  readonly PUBLIC_STAKE_POOL_ID: string;
  readonly PUBLIC_SWAP_ON_CETUS_LINK: string;
  readonly PUBLIC_PROVIDE_LIQUIDITY_ON_CETUS_LINK: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

type ENV = {
  LISUIFY_KV_NAMESPACE: KVNamespace;
};

declare global {
  declare namespace App {
    interface Locals extends DirectoryRuntime<ENV> {}
  }
}
