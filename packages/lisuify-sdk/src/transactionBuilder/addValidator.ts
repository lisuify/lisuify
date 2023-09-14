import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';
import {TransactionBlock} from '@mysten/sui.js/transactions';

export const addValidator = ({
  lisuifyId,
  poolId,
  validatorPool,
  address,
  cap,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  validatorPool: string;
  address: string;
  cap: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::add_validator`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // validator_pool
      txb.pure(validatorPool),
      // validator_address
      txb.pure(address),
      // cap
      txb.object(cap),
    ],
  });
};
