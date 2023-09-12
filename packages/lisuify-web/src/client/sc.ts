import { StakePool } from "@lisuify/sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { lisuifyId, stakePoolId } from "../consts";
import { client } from "./client";
import { walletKit } from "../stores/walletStore";

export const depositSUI = async (amount: bigint) => {
  const txb = new TransactionBlock();
  const stakePool = await StakePool.load({
    provider: client,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  stakePool.depositSui({ amount, txb });

  return walletKit.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showEffects: true,
    },
  });
};

export const depositStakedSUI = async ({ objectId }: { objectId: string }) => {
  const txb = new TransactionBlock();
  const stakePool = await StakePool.load({
    provider: client,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  stakePool.depositStake({
    stake: objectId,
    txb,
  });

  return walletKit.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showEffects: true,
    },
  });
};
