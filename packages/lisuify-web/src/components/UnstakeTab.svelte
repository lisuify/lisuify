<script lang="ts">
  import LiSuiLogo from "./icons/LiSuiLogo.svelte";
  import { walletStateAtom } from "../stores/walletStore";
  import { blockExplorerLink, log, suiToString } from "../utils";
  import { callWallet, withdrawSUI } from "../client/lisuify";
  import { addToastMessage } from "../stores/toastStore";
  import { suiDecimal } from "../consts";

  let liSuiAmountBigint = BigInt(0);
  let liSuiAmount = "";
  let liSuiAmountError = "";

  const handlAmount = (target: string) => {
    liSuiAmountError = "";
    liSuiAmount = target;
    if (
      Number.isFinite(liSuiAmount) ||
      Number.isNaN(liSuiAmount) ||
      Number.isNaN(Number.parseFloat(liSuiAmount)) ||
      Number(liSuiAmount) <= 0
    ) {
      liSuiAmountError = "liSUI amount is invalid";
      return;
    }
    liSuiAmountBigint = BigInt(Number(liSuiAmount) * 10 ** suiDecimal);
  };

  const handleStake = async () => {
    // stake SUI coins
    const txb = await withdrawSUI(
      $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiCoins,
      liSuiAmountBigint
    );

    callWallet(txb)
      .then((object) => {
        if (object.errors) {
          log("withdrawSUI errors:", object.errors);
          addToastMessage(
            `Error to unstake: ${object.errors}`,
            "error",
            blockExplorerLink(object.digest)
          );
          return;
        }
        log("withdrawSUI success:", object);
        addToastMessage(
          `Successfully unstaked ${liSuiAmount} liSUI!`,
          "success",
          blockExplorerLink(object.digest)
        );
      })
      .catch((e: Error) => {
        if (e.message.includes("Rejected from user")) {
          addToastMessage("Rejected by the user", "info");
          return;
        }
        console.error("withdrawSUI error:", e);
        addToastMessage(
          `Error to unstake ${liSuiAmount} liSUI: ${e.message}`,
          "error"
        );
      });
  };
</script>

<div class="flex text-end">
  Balance: {suiToString(
    $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiBalance
  )} liSUI
</div>
<div
  class="flex w-full p-0 btn-group h-12 input input-bordered {liSuiAmountError &&
    'border-error'}"
>
  <div class="p-2" style="fill:#6fbcf0"><LiSuiLogo /></div>
  <input
    type="number"
    placeholder="liSUI amount"
    class="flex-grow px-2 bg-base-100 w-full outline-none text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
    value={liSuiAmount}
    on:input={(e) => {
      handlAmount(e.currentTarget.value);
    }}
  />
  <button
    class="btn btn-ghost primary h-full"
    on:click={() => {
      handlAmount(
        (
          Number(
            $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiBalance
          ) /
          10 ** suiDecimal
        ).toString()
      );
    }}>MAX</button
  >
</div>
{#if liSuiAmountError}
  <div class="flex w-full p-0 h-12 text-error justify-center items-center">
    {liSuiAmountError}
  </div>
{/if}

<div class="flex justify-between w-full">
  <div>You will receive</div>
  <div>0 SUI</div>
</div>

<div class="flex justify-between w-full">
  <div>Exchange rate</div>
  <div>1 liSUI = 1.01 SUI</div>
</div>

<button
  class="btn btn-primary w-full"
  on:click={handleStake}
  disabled={liSuiAmount === "" || !!liSuiAmountError}
>
  UNSTAKE
</button>
