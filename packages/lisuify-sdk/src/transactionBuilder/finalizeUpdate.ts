import {TransactionBlock} from '@mysten/sui.js/transactions';

export const finalizeUpdate = ({
  lisuifyId,
  poolId,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::finalize_update`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
    ],
  });
};
