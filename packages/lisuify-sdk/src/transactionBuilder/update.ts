import {TransactionBlock} from '@mysten/sui.js/transactions';
import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';

export const update = ({
  lisuifyId,
  poolId,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::update`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // max_validators
      // eslint-disable-next-line node/no-unsupported-features/es-builtins
      txb.pure(BigInt('18446744073709551615')),
    ],
  });
};
