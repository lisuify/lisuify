import {TransactionBlock} from '@mysten/sui.js/transactions';

export const addValidator = ({
  lisuifyId,
  poolId,
  validatorPool,
  cap,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  validatorPool: string;
  cap: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::add_validator`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // validator_pool
      txb.object(validatorPool),
      // cap
      txb.object(cap),
    ],
  });
};
