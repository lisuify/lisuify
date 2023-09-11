import {Command} from 'commander';
import {context} from '../context';
import {StakePool} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {lisuifyId, stakePoolId} from '../keys';
import {execute} from '../execute';

export const installUpdate = (program: Command) => {
  program
    .command('update')
    .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
    .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
    .action(update);
};

const update = async ({lisuify, poolId}: {lisuify: string; poolId: string}) => {
  const stakePool = await StakePool.load({
    provider: context.provider,
    lisuifyId: lisuify,
    id: poolId,
  });

  const txb = new TransactionBlock();
  stakePool.update({
    provider: context.provider,
    txb,
  });

  await execute(txb);
};
