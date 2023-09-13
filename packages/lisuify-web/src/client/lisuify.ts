import { StakePool } from "@lisuify/sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { lisuifyId, originalLisuifyId, stakePoolId } from "../consts";
import { client } from "./client";
import { walletKit } from "../stores/walletStore";
import type { CoinStruct } from "@mysten/sui.js/client";
import { addToastMessage } from "../stores/toastStore";

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
  await initialStakePool();
} catch (e) {
  addToastMessage(`Failed to initialize stake pool: ${e}`, "error");
}

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
  return client.dryRunTransactionBlock({
    transactionBlock: txb.serialize(),
  });
};

export const getLiSUIRatio = async () => {
  // TODO fix this
  console.log("stakePool.lastUpdateSuiBalance", stakePool.lastUpdateSuiBalance);
  console.log(
    "stakePool.lastUpdateTokenSupply",
    stakePool.lastUpdateTokenSupply
  );
  return BigInt(101);
};

export const callWallet = async (txb: TransactionBlock) => {
  return walletKit.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showEffects: true,
    },
  });
};
