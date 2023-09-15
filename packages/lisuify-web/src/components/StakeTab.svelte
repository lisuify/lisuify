<script lang="ts">
  import SuiLogo from "./icons/SuiLogo.svelte";
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
    depositSUI,
    depositStakedSUI,
    dryRunTransactionBlock,
    liSuiCoinType,
  } from "../client/lisuify";
  import { addToastMessage } from "../stores/toastStore";
  import { statsAtom } from "../stores/statsStore";
  import type { TransactionBlock } from "@mysten/sui.js/transactions";
  import { SUI_DECIMALS } from "@mysten/sui.js/utils";

  let selectingIndex = -1;
  let suiAmountBigint = BigInt(0);
  let suiAmount = "";
  let suiAmountError = "";
  let stakedSuiAmountBigint = BigInt(0);
  let liSuiBalanceChange = BigInt(0);
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
    suiAmountError = "";
    suiAmount = target;
    if (Number(suiAmount) < 0.1) {
      suiAmountError = "SUI amount must more than 0.1";
      return;
    }
    if (
      Number(suiAmount) >
      suiToNumber(
        $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
      )
    ) {
      suiAmountError = "SUI amount must not more than balance";
      return;
    }
    if (
      Number.isFinite(suiAmount) ||
      Number.isNaN(suiAmount) ||
      Number.isNaN(Number.parseFloat(suiAmount))
    ) {
      suiAmountError = "SUI amount is invalid";
      return;
    }
    suiAmountBigint = BigInt(Number(suiAmount) * 10 ** SUI_DECIMALS);

    // simulate stake SUI coins
    txb = await depositSUI(suiAmountBigint);
    txb.setSender(
      $walletStateAtom.wallets[$walletStateAtom.walletIdx].walletAccount.address
    );
    loadingSimulateTx = true;
    dryRunTransactionBlock(txb)
      .then((resp) => {
        log("dryRunTransactionBlock", resp);
        resp.balanceChanges.forEach((balance) => {
          if (balance.coinType === liSuiCoinType) {
            liSuiBalanceChange = BigInt(balance.amount);
            liSuiRatio = Number(suiAmountBigint) / Number(liSuiBalanceChange);
          }
        });
        loadingSimulateTx = false;
      })
      .catch((e: Error) => {
        addToastMessage(`Error to simulate stake SUI: ${e.message}`, "error");
        loadingSimulateTx = false;
      });
  };

  const handleDropdown = async (index: number) => {
    selectingIndex = index;
    // simulate stake StakedSUI
    if (selectingIndex >= 0) {
      const stakedSuiObjects =
        $walletStateAtom.wallets[$walletStateAtom.walletIdx].stakedSuiObjects[
          selectingIndex
        ];
      stakedSuiAmountBigint =
        BigInt(stakedSuiObjects.content?.fields?.principal) || BigInt(0);
      txb = await depositStakedSUI({
        objectId: stakedSuiObjects.objectId,
      });
      txb.setSender(
        $walletStateAtom.wallets[$walletStateAtom.walletIdx].walletAccount
          .address
      );
      loadingSimulateTx = true;
      dryRunTransactionBlock(txb)
        .then((resp) => {
          log("dryRunTransactionBlock", resp);
          resp.balanceChanges.forEach((balance) => {
            if (balance.coinType === liSuiCoinType) {
              liSuiBalanceChange = BigInt(balance.amount);
              liSuiRatio =
                Number(stakedSuiAmountBigint) / Number(liSuiBalanceChange);
            }
          });
          loadingSimulateTx = false;
        })
        .catch((e: Error) => {
          addToastMessage(
            `Error to simulate stake ${suiToString(
              stakedSuiAmountBigint
            )} SUI: ${e.message}`,
            "error"
          );
          loadingSimulateTx = false;
        });
    }
  };

  const handleStake = async () => {
    if (selectingIndex >= 0) {
      callWallet(txb)
        .then((object) => {
          if (object.errors) {
            log("depositStakedSUI errors:", object.errors);
            addToastMessage(
              `Error to stake: ${object.errors}`,
              "error",
              blockExplorerLink(object.digest)
            );
            return;
          }
          log("depositStake success:", object);
          addToastMessage(
            `Successfully staked ${suiToString(stakedSuiAmountBigint)} SUI!`,
            "success",
            blockExplorerLink(object.digest)
          );
        })
        .catch((e: Error) => {
          if (e.message.includes("Rejected from user")) {
            addToastMessage("Rejected by the user", "info");
            return;
          }
          console.error("depositStakedSUI error:", e);
          addToastMessage(
            `Error to stake ${suiToString(stakedSuiAmountBigint)} SUI: ${
              e.message
            }`,
            "error"
          );
        });
      return;
    }

    callWallet(txb)
      .then((object) => {
        if (object.errors) {
          log("depositSUI errors:", object.errors);
          addToastMessage(
            `Error to stake: ${object.errors}`,
            "error",
            blockExplorerLink(object.digest)
          );
          return;
        }
        log("depositSUI success:", object);
        getWalletBalances();
        addToastMessage(
          `Successfully staked ${suiAmount} SUI!`,
          "success",
          blockExplorerLink(object.digest)
        );
      })
      .catch((e: Error) => {
        if (e.message.includes("Rejected from user")) {
          addToastMessage("Rejected by the user", "info");
          return;
        }
        console.error("depositSUI error:", e);
        addToastMessage(
          `Error to stake ${suiAmount} SUI: ${e.message}`,
          "error"
        );
      });
  };
</script>

<div class="dropdown dropdown-bottom dropdown-end w-full">
  {#if selectingIndex < 0}
    <button class="btn btn-outline w-full bg-base-100 flex">
      <div class="flex-grow text-xs lg:text-sm">SUI Coins</div>
      <div class="flex flex-col items-end text-xs font-thin">
        <div>balance</div>
        <div>
          {suiToString(
            $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
          )} SUI
        </div>
      </div>
      <div class="h-full py-2" style="fill:#6fbcf0"><SuiLogo /></div>
    </button>
  {:else}
    <button class="btn btn-outline w-full bg-base-100 flex">
      <div class="flex-grow text-xs lg:text-sm">
        Staked SUI: {$walletStateAtom.wallets[$walletStateAtom.walletIdx]
          .stakedSuiObjects[selectingIndex]?.validator?.name}
      </div>
      <div class="flex flex-col items-end text-xs font-thin">
        <div>principal</div>
        <div>
          {suiToString(
            BigInt(
              $walletStateAtom.wallets[$walletStateAtom.walletIdx]
                .stakedSuiObjects[selectingIndex]?.content?.fields?.principal
            ) || 0
          )} SUI
        </div>
      </div>
      <div class="h-full py-2 fill-primary">
        {#if $walletStateAtom.wallets[$walletStateAtom.walletIdx]?.stakedSuiObjects[selectingIndex].validator?.imageUrl}
          <img
            alt={$walletStateAtom.wallets[$walletStateAtom.walletIdx]
              ?.stakedSuiObjects[selectingIndex].validator?.name}
            class="h-full aspect-square rounded-full bg-white"
            src={$walletStateAtom.wallets[$walletStateAtom.walletIdx]
              ?.stakedSuiObjects[selectingIndex].validator?.imageUrl}
          />
        {:else}
          <SuiLogo />
        {/if}
      </div>
    </button>
  {/if}
  <div
    class="dropdown-content z-[1] text-primary-content flex flex-col gap-1 pt-1 w-full"
  >
    {#if selectingIndex >= 0}
      <button
        class="btn btn-outline w-full bg-base-100 flex"
        on:click={() => {
          handleDropdown(-1);
        }}
      >
        <div class="flex-grow text-xs lg:text-sm">SUI Coins</div>
        <div class="flex flex-col items-end text-xs font-thin">
          <div>balance</div>
          <div>
            {suiToString(
              $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
            )} SUI
          </div>
        </div>
        <div class="h-full py-2" style="fill:#6fbcf0"><SuiLogo /></div>
      </button>
    {/if}
    {#each $walletStateAtom.wallets[$walletStateAtom.walletIdx].stakedSuiObjects as stakedSUI, index (stakedSUI.objectId)}
      {#if selectingIndex !== index}
        <button
          class="btn btn-outline w-full bg-base-100 flex"
          on:click={() => {
            handleDropdown(index);
          }}
        >
          <div class="flex-grow text-xs lg:text-sm">
            Staked SUI: {stakedSUI?.validator?.name}
          </div>
          <div class="flex flex-col items-end text-xs font-thin">
            <div>principal</div>
            <div>
              {suiToString(BigInt(stakedSUI.content?.fields?.principal) || 0)} SUI
            </div>
          </div>
          <div class="h-full py-2 fill-primary">
            {#if stakedSUI.validator?.imageUrl}
              <img
                alt={stakedSUI.validator?.name}
                class="h-full aspect-square rounded-full bg-white"
                src={stakedSUI.validator?.imageUrl}
              />
            {:else}
              <SuiLogo />
            {/if}
          </div>
        </button>
      {/if}
    {/each}
  </div>
</div>

{#if selectingIndex < 0}
  <div
    class="flex w-full p-0 btn-group h-12 input input-bordered {suiAmountError &&
      'border-error'}"
  >
    <div class="p-2 select-none" style="fill:#6fbcf0"><SuiLogo /></div>
    <input
      type="number"
      placeholder="SUI amount"
      class="flex-grow px-2 bg-base-100 w-full outline-none text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
      value={suiAmount}
      on:input={(e) => {
        onInput(e.currentTarget.value);
      }}
    />
    <button
      class="btn btn-ghost primary h-full"
      on:click={() => {
        handleAmount(
          suiToString(
            Math.max(
              Number(
                $walletStateAtom.wallets[$walletStateAtom.walletIdx].suiBalance
              ) -
                10 ** 8,
              0
            )
          )
        );
      }}>MAX</button
    >
  </div>
  {#if suiAmountError}
    <div class="flex w-full p-0 h-12 text-error justify-center items-center">
      {suiAmountError}
    </div>
  {/if}
{/if}

<div
  class="flex flex-col gap-2 w-full {loadingSimulateTx &&
    'animate-pulse blur-sm'}"
>
  <div class="flex justify-between w-full">
    <div>You will receive</div>
    <div>{suiToString(liSuiBalanceChange)} liSUI</div>
  </div>

  <div class="flex justify-between w-full">
    <div>Exchange rate</div>
    <div>1 liSUI = {round(liSuiRatio)} SUI</div>
  </div>

  <div class="flex justify-between w-full">
    <div>APY</div>
    <div>{round($statsAtom.validatorApy, 2)} %</div>
  </div>
</div>

<button
  class="btn btn-primary w-full"
  on:click={handleStake}
  disabled={!txb ||
    (selectingIndex < 0 && (suiAmount === "" || !!suiAmountError))}
>
  STAKE
</button>
