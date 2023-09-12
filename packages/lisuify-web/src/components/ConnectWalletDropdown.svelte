<script lang="ts">
  import {
    disconnectWallet,
    walletStateAtom,
    changeWallet,
  } from "../stores/walletStore";
  import { round, shortAddress, suiToString } from "../utils";
  import ConnectWalletButton from "./ConnectWalletButton.svelte";
</script>

{#if $walletStateAtom.wallets.length > 0}
  <div class="dropdown dropdown-bottom dropdown-end w-64">
    <button
      class="btn rounded-full w-full flex justify-between bg-base-200 border-base-300"
    >
      <div>
        {shortAddress(
          $walletStateAtom.wallets[$walletStateAtom.walletIdx].walletAccount
            .address
        )}
      </div>
      <div>
        {`${suiToString(
          $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
        )} SUI`}
      </div>
    </button>
    <div
      class="dropdown-content z-[1] text-primary-content flex flex-col gap-1 pt-1 w-full"
    >
      {#each $walletStateAtom.wallets as wallet, index}
        {#if index !== $walletStateAtom.walletIdx}
          <button
            class="btn rounded-full w-full flex justify-between bg-base-200 border-base-300"
            on:click={() => {
              changeWallet(index);
            }}
          >
            <div>
              {shortAddress(wallet.walletAccount.address)}
            </div>
            <div>
              {`${suiToString(wallet.suiBalance)} SUI`}
            </div>
          </button>
        {/if}
      {/each}
      <button
        class="btn btn-error w-full rounded-full border-base-300"
        on:click={async () => {
          await disconnectWallet();
        }}>Disconnect</button
      >
    </div>
  </div>
{:else}
  <ConnectWalletButton />
{/if}
