import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';

export const installDepositStake = (program: Command) => {
  program
    .command('deposit-stake')
    .argument('stake', 'Staked SUI object')
    .action(depositStake);
};

const depositStake = async (stake: string) => {
  const txb = new TransactionBlock();
  context.stakePool.depositStake({
    stake,
    txb,
  });

  await execute(txb);
};
