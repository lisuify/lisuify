import { StakePool } from "@lisuify/sdk";
import { TransactionBlock } from "@mysten/sui.js/transactions";
import { lisuifyId, originalLisuifyId, stakePoolId } from "../consts";
import { client } from "./client";
import { walletKit } from "../stores/walletStore";
import type { CoinStruct } from "@mysten/sui.js/client";

export const depositSUI = async (amount: bigint) => {
  const txb = new TransactionBlock();
  const stakePool = await StakePool.load({
    provider: client,
    originalLisuifyId: originalLisuifyId,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  stakePool.depositSui({ amount, txb });

  return txb;
};

export const depositStakedSUI = async ({ objectId }: { objectId: string }) => {
  const txb = new TransactionBlock();
  const stakePool = await StakePool.load({
    provider: client,
    originalLisuifyId: originalLisuifyId,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  stakePool.depositStake({
    stake: objectId,
    txb,
  });

  return txb;
};

export const withdrawSUI = async (liSuiCoins: CoinStruct[], amount: bigint) => {
  const txb = new TransactionBlock();
  const stakePool = await StakePool.load({
    provider: client,
    originalLisuifyId: originalLisuifyId,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  stakePool.withdraw({ coins: liSuiCoins, amount, txb });

  return txb;
};

export const dryRunTransactionBlock = async (txb: TransactionBlock) => {
  return client.dryRunTransactionBlock({
    transactionBlock: txb.serialize(),
  });
};

export const getLiSUIRatio = async () => {
  const stakePool = await StakePool.load({
    provider: client,
    originalLisuifyId: originalLisuifyId,
    lisuifyId: lisuifyId,
    id: stakePoolId,
  });
  return stakePool.lastUpdateSuiBalance / stakePool.lastUpdateTokenSupply;
};

export const callWallet = async (txb: TransactionBlock) => {
  return walletKit.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    options: {
      showEffects: true,
    },
  });
};
