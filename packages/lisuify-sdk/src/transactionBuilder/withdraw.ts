import {
  TransactionArgument,
  TransactionBlock,
} from '@mysten/sui.js/transactions';
import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';

export const withdraw = ({
  lisuifyId,
  poolId,
  token,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  token: TransactionArgument;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::withdraw`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // token
      token,
    ],
  });
};
