import {TransactionBlock} from '@mysten/sui.js/transactions';
import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';

export const depositStake = ({
  lisuifyId,
  poolId,
  stake,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  stake: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::deposit_stake`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // stake
      txb.object(stake),
    ],
  });
};
