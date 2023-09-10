import {TransactionBlock} from '@mysten/sui.js/transactions';

export const setStakingValidator = ({
  lisuifyId,
  poolId,
  address = null,
  cap,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  address?: string | null;
  cap: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::set_staking_validator`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // v
      txb.pure(address ? [address] : []),
      // cap
      txb.object(cap),
    ],
  });
};
