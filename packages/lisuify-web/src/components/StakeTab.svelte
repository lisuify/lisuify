<script lang="ts">
  import SuiLogo from "./icons/SuiLogo.svelte";
  import { getWalletBalances, walletStateAtom } from "../stores/walletStore";
  import { blockExplorerLink, log, suiToString } from "../utils";
  import { callWallet, depositSUI, depositStakedSUI } from "../client/lisuify";
  import { addToastMessage } from "../stores/toastStore";
  import { suiDecimal } from "../consts";

  let selectingIndex = -1;
  let suiAmountBigint = BigInt(0);
  let suiAmount = "";
  let suiAmountError = "";

  const handlAmount = (target: string) => {
    suiAmountError = "";
    suiAmount = target;
    if (Number(suiAmount) < 0.1) {
      suiAmountError = "SUI amount must more than 0.1";
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
    suiAmountBigint = BigInt(Number(suiAmount) * 10 ** suiDecimal);
  };

  const handleStake = async () => {
    // Stake Staked SUI Object
    if (selectingIndex >= 0) {
      const stakedSuiObjects =
        $walletStateAtom.wallets[$walletStateAtom.walletIdx].stakedSuiObjects[
          selectingIndex
        ];

      const suiString = suiToString(
        BigInt(stakedSuiObjects.content?.fields?.principal) || 0
      );

      const txb = await depositStakedSUI({
        objectId: stakedSuiObjects.objectId,
      });

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
            `Successfully staked ${suiString} SUI!`,
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
            `Error to stake ${suiString} SUI: ${e.message}`,
            "error"
          );
        });

      return;
    }

    // stake SUI coins
    const txb = await depositSUI(suiAmountBigint);

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
      <div class="flex-grow text-xs md:text-sm">SUI Coins</div>
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
      <div class="flex-grow text-xs md:text-sm">
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
          selectingIndex = -1;
        }}
      >
        <div class="flex-grow text-xs md:text-sm">SUI Coins</div>
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
            selectingIndex = index;
          }}
        >
          <div class="flex-grow text-xs md:text-sm">
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
    <div class="p-2" style="fill:#6fbcf0"><SuiLogo /></div>
    <input
      type="number"
      placeholder="SUI amount"
      class="flex-grow px-2 bg-base-100 w-full outline-none text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
      value={suiAmount}
      on:input={(e) => {
        handlAmount(e.currentTarget.value);
      }}
    />
    <button
      class="btn btn-ghost primary h-full"
      on:click={() => {
        handlAmount(
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

<div class="flex justify-between w-full">
  <div>You will receive</div>
  <div>0 liSUI</div>
</div>

<div class="flex justify-between w-full">
  <div>Exchange rate</div>
  <div>1 liSUI = 1.01 SUI</div>
</div>

<div class="flex justify-between w-full">
  <div>APY</div>
  <div>5.5 %</div>
</div>

<button
  class="btn btn-primary w-full"
  on:click={handleStake}
  disabled={selectingIndex < 0 && (suiAmount === "" || !!suiAmountError)}
>
  STAKE
</button>
