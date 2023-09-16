import {TransactionBlock} from '@mysten/sui.js/transactions';
import {
  SUI_CLOCK_OBJECT_ID,
  SUI_SYSTEM_STATE_OBJECT_ID,
} from '@mysten/sui.js/utils';

/*
stake_reserve<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        validator_address: address,
        ctx: &mut TxContext,
    )
*/

export const stakeReserve = ({
  lisuifyId,
  poolId,
  validatorAddress,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  validatorAddress: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::stake_reserve`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // clock
      txb.object(SUI_CLOCK_OBJECT_ID),
      // validator address
      txb.pure(validatorAddress),
    ],
  });
};
