<script lang="ts">
  import { fade } from "svelte/transition";
  import { loadingWalletDataAtom } from "../stores/loadingStore";
  import { getWalletBalances, walletStateAtom } from "../stores/walletStore";
  import ConnectWalletButton from "./ConnectWalletButton.svelte";
  import StakeTab from "./StakeTab.svelte";
  import UnstakeTab from "./UnstakeTab.svelte";

  let isStake = true;
</script>

<div
  class="{$loadingWalletDataAtom &&
    'animate-pulse blur-sm pointer-events-none'} w-full max-w-lg p-4 flex flex-col items-center gap-4 rounded-lg border border-base-100 bg-base-100 relative"
>
  {#if $walletStateAtom.wallets.length > 0}
    <button
      class="absolute top-1 right-1 cursor-pointer text-neutral"
      on:click={getWalletBalances}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-4 h-4"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99"
        />
      </svg>
    </button>
    <div class="w-full btn-group pt-2">
      <button
        class={`flex-grow btn btn-secondary ${!isStake && "btn-outline"}`}
        on:click={() => {
          isStake = true;
        }}
      >
        STAKE
      </button>
      <button
        class={`flex-grow btn btn-secondary ${isStake && "btn-outline"}`}
        on:click={() => {
          isStake = false;
        }}
      >
        UNSTAKE
      </button>
    </div>
    {#if isStake}
      <div
        class="w-full flex flex-col gap-4 justify-center items-center"
        in:fade={{
          duration: 300,
        }}
      >
        <StakeTab />
      </div>
    {:else}
      <div
        class="w-full flex flex-col gap-4 justify-center items-center"
        in:fade={{
          duration: 300,
        }}
      >
        <UnstakeTab />
      </div>
    {/if}
  {:else}
    <div class="h-48 flex flex-col justify-evenly">
      <div>Connect wallet to use LiSuify</div>
      <ConnectWalletButton />
    </div>
  {/if}
</div>
