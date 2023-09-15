<script lang="ts">
  import { loadingWalletDataAtom } from "../stores/loadingStore";
  import {
    disconnectWallet,
    walletStateAtom,
    changeWallet,
  } from "../stores/walletStore";
  import { shortAddress, suiToString } from "../utils";
  import ConnectWalletButton from "./ConnectWalletButton.svelte";
</script>

{#if $walletStateAtom.wallets.length > 0}
  <div
    class="dropdown dropdown-bottom dropdown-end w-72 {$loadingWalletDataAtom &&
      'animate-pulse blur-sm pointer-events-none'}"
  >
    <button
      class="btn rounded-full w-full flex justify-between bg-base-100 border-base-300"
    >
      <div>
        {shortAddress(
          $walletStateAtom.wallets[$walletStateAtom.walletIdx].walletAccount
            .address
        )}
      </div>
      <div class="flex flex-col text-xs">
        <div class="flex gap-x-2">
          <div class="text-right">
            {suiToString(
              $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
            )}
          </div>
          <div class="text-left">SUI</div>
        </div>
        <div class="flex gap-x-2">
          <div class="text-right">
            {suiToString(
              $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiBalance
            )}
          </div>
          <div class="text-left">liSUI</div>
        </div>
      </div>
    </button>
    <div
      class="dropdown-content z-[1] text-primary-content flex flex-col gap-1 pt-1 w-full"
    >
      {#each $walletStateAtom.wallets as wallet, index}
        {#if index !== $walletStateAtom.walletIdx}
          <button
            class="btn rounded-full w-full flex justify-between bg-base-100 border-base-300"
            on:click={() => {
              changeWallet(index);
            }}
          >
            <div>
              {shortAddress(wallet.walletAccount.address)}
            </div>
            <div class="flex flex-col text-xs">
              <div class="flex gap-x-2">
                <div class="text-right">
                  {suiToString(wallet.suiBalance)}
                </div>
                <div class="text-left">SUI</div>
              </div>
              <div class="flex gap-x-2">
                <div class="text-right">
                  {suiToString(wallet.liSuiBalance)}
                </div>
                <div class="text-left">liSUI</div>
              </div>
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
