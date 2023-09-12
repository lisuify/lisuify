import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';

export const installDepositSui = (program: Command) => {
  program
    .command('deposit-sui')
    .argument('amount', 'Sui amount')
    .action(depositSui);
};

const depositSui = async (amount: string) => {
  const txb = new TransactionBlock();
  context.stakePool.depositSui({
    // eslint-disable-next-line node/no-unsupported-features/es-builtins
    amount: BigInt(parseFloat(amount) * Math.pow(10, SUI_DECIMALS)),
    txb,
  });

  await execute(txb);
};
