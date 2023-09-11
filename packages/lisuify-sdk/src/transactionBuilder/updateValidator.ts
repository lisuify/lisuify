import {TransactionBlock} from '@mysten/sui.js/transactions';
import {SUI_SYSTEM_STATE_OBJECT_ID} from '@mysten/sui.js/utils';

export const updateValidator = ({
  lisuifyId,
  poolId,
  validatorPoolId,
  txb,
}: {
  lisuifyId: string;
  poolId: string;
  validatorPoolId: string;
  txb: TransactionBlock;
}) => {
  txb.moveCall({
    target: `${lisuifyId}::stake_pool::update_validator`,
    typeArguments: [`${lisuifyId}::coin::COIN`],
    arguments: [
      // self
      txb.object(poolId),
      // sui_system
      txb.object(SUI_SYSTEM_STATE_OBJECT_ID),
      // validator_pool_id
      txb.object(validatorPoolId),
    ],
  });
};
