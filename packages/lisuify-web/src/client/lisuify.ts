import { StakePool } from "@lisuify/sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { lisuifyId, originalLisuifyId, stakePoolId } from "../consts";
import { client } from "./client";
import { walletKit } from "../stores/walletStore";
import type { CoinStruct } from "@mysten/sui.js/client";
import { addToastMessage } from "../stores/toastStore";
import { log } from "../utils";

let stakePool: StakePool;

const initialStakePool = async () => {
  stakePool = await StakePool.load({
    provider: client,
    originalLisuifyId: originalLisuifyId,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
};

try {
  initialStakePool();
} catch (e) {
  addToastMessage(`Failed to initialize stake pool: ${e}`, "error");
}

export const liSuiCoinType = `${originalLisuifyId}::coin::COIN`;

export const depositSUI = async (amount: bigint) => {
  const txb = new TransactionBlock();
  stakePool.depositSui({ amount, txb });

  return txb;
};

export const depositStakedSUI = async ({ objectId }: { objectId: string }) => {
  const txb = new TransactionBlock();

  stakePool.depositStake({
    stake: objectId,
    txb,
  });

  return txb;
};

export const withdrawSUI = async (liSuiCoins: CoinStruct[], amount: bigint) => {
  const txb = new TransactionBlock();

  stakePool.withdraw({ coins: liSuiCoins, amount, txb });

  return txb;
};

export const dryRunTransactionBlock = async (txb: TransactionBlock) => {
  const txbArray = await txb.build({
    client: client,
  });
  return client.dryRunTransactionBlock({
    transactionBlock: txbArray,
  });
};

export const getCurrentSuiBalance = async () => {
  return stakePool.currentSuiBalance;
};

export const getLiSUIRatio = async () => {
  log("stakePool.lastUpdateSuiBalance", stakePool.lastUpdateSuiBalance);
  log("stakePool.lastUpdateTokenSupply", stakePool.lastUpdateTokenSupply);
  if (stakePool.lastUpdateTokenSupply <= 0) {
    return 1; // use 1 to prevent zero division
  }
  return (
    Number(stakePool.lastUpdateSuiBalance) /
    Number(stakePool.lastUpdateTokenSupply)
  );
};

export const callWallet = async (txb: TransactionBlock) => {
  return walletKit.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showEffects: true,
    },
  });
};
