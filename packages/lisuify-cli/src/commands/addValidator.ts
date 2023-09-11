import {Command} from 'commander';
import {context} from '../context';
import {StakePool} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {lisuifyId, stakePoolId} from '../keys';
import {execute} from '../execute';

export const installAddValidator = (program: Command) => {
  program
    .command('add-validator')
    .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
    .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
    .requiredOption('--validator <address>', 'Validator pool id')
    .action(addValidator);
};

const addValidator = async ({
  lisuify,
  poolId,
  validator,
}: {
  lisuify: string;
  poolId: string;
  validator: string;
}) => {
  const stakePool = await StakePool.load({
    provider: context.provider,
    lisuifyId: lisuify,
    id: poolId,
  });

  const txb = new TransactionBlock();
  stakePool.addValidator({
    validatorPool: validator,
    txb,
  });

  await execute(txb);
};
