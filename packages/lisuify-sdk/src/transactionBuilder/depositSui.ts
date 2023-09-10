import {TransactionBlock} from '@mysten/sui.js/transactions';
import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';

export const depositSui = ({
  lisuifyId,
  poolId,
  sui,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  sui: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::deposit_sui`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // sui
      // txb.mergeCoins(),
    ],
  });
};
