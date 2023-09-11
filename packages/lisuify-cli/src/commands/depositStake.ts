import {Command} from 'commander';
import {context} from '../context';
import {StakePool} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {lisuifyId, stakePoolId} from '../keys';
import {execute} from '../execute';

export const installDepositStake = (program: Command) => {
  program
    .command('deposit-stake')
    .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
    .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
    .requiredOption('--stake <address>', 'Staked SUI object')
    .action(depositStake);
};

const depositStake = async ({
  lisuify,
  poolId,
  stake,
}: {
  lisuify: string;
  poolId: string;
  stake: string;
}) => {
  const stakePool = await StakePool.load({
    provider: context.provider,
    lisuifyId: lisuify,
    id: poolId,
  });

  const txb = new TransactionBlock();
  stakePool.depositStake({
    stake,
    txb,
  });

  await execute(txb);
};
