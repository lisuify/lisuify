<script lang="ts">
  import LiSuiLogo from "./icons/LiSuiLogo.svelte";
  import { getWalletBalances, walletStateAtom } from "../stores/walletStore";
  import {
    blockExplorerLink,
    log,
    round,
    suiToNumber,
    suiToString,
  } from "../utils";
  import {
    callWallet,
    dryRunTransactionBlock,
    withdrawSUI,
  } from "../client/lisuify";
  import { addToastMessage } from "../stores/toastStore";
  import type { TransactionBlock } from "@mysten/sui.js/transactions";
  import { statsAtom } from "../stores/statsStore";
  import { SUI_DECIMALS, SUI_TYPE_ARG } from "@mysten/sui.js/utils";

  let liSuiAmountBigint = BigInt(0);
  let liSuiAmount = "";
  let liSuiAmountError = "";
  let suiBalanceChange = BigInt(0);
  let liSuiRatio = $statsAtom.liSuiRatio;
  let txb: TransactionBlock;
  let loadingSimulateTx = false;

  // use to trigger when stop typing for 1 second
  let inputTimeout: NodeJS.Timeout;
  const onInput = (target: string) => {
    clearTimeout(inputTimeout);
    inputTimeout = setTimeout(function () {
      handleAmount(target);
    }, 1000);
  };

  const handleAmount = async (target: string) => {
    liSuiAmountError = "";
    liSuiAmount = target;
    if (
      Number(liSuiAmount) >
      suiToNumber(
        $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiBalance
      )
    ) {
      liSuiAmountError = "liSUI amount must not more than balance";
      return;
    }
    if (
      Number.isFinite(liSuiAmount) ||
      Number.isNaN(liSuiAmount) ||
      Number.isNaN(Number.parseFloat(liSuiAmount)) ||
      Number(liSuiAmount) <= 0
    ) {
      liSuiAmountError = "liSUI amount is invalid";
      return;
    }
    liSuiAmountBigint = BigInt(Number(liSuiAmount) * 10 ** SUI_DECIMALS);

    // stake SUI coins
    txb = await withdrawSUI(
      $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiCoins,
      liSuiAmountBigint
    );
    txb.setSender(
      $walletStateAtom.wallets[$walletStateAtom.walletIdx].walletAccount.address
    );
    loadingSimulateTx = true;
    dryRunTransactionBlock(txb)
      .then((resp) => {
        log("dryRunTransactionBlock", resp);
        resp.balanceChanges.forEach((balance) => {
          if (balance.coinType === SUI_TYPE_ARG) {
            suiBalanceChange = BigInt(balance.amount);
            liSuiRatio = Number(suiBalanceChange) / Number(liSuiAmountBigint);
          }
        });
        loadingSimulateTx = false;
      })
      .catch((e: Error) => {
        addToastMessage(`Error to simulate stake SUI: ${e.message}`, "error");
        loadingSimulateTx = false;
      });
  };

  const handleStake = async () => {
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
        getWalletBalances();
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
  <div class="p-2 select-none" style="fill:#6fbcf0"><LiSuiLogo /></div>
  <input
    type="number"
    placeholder="liSUI amount"
    class="flex-grow px-2 bg-base-100 w-full outline-none text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
    value={liSuiAmount}
    on:input={(e) => {
      onInput(e.currentTarget.value);
    }}
  />
  <button
    class="btn btn-ghost primary h-full"
    on:click={() => {
      handleAmount(
        (
          Number(
            $walletStateAtom.wallets[$walletStateAtom.walletIdx].liSuiBalance
          ) /
          10 ** SUI_DECIMALS
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

<div
  class="flex flex-col gap-2 w-full {loadingSimulateTx &&
    'animate-pulse blur-sm'}"
>
  <div class="flex justify-between w-full">
    <div>You will receive</div>
    <div>{suiToString(suiBalanceChange)} SUI</div>
  </div>

  <div class="flex justify-between w-full">
    <div>Exchange rate</div>
    <div>1 liSUI = {round(liSuiRatio)} SUI</div>
  </div>
</div>

<button
  class="btn btn-primary w-full"
  on:click={handleStake}
  disabled={liSuiAmount === "" || !!liSuiAmountError}
>
  UNSTAKE
</button>
