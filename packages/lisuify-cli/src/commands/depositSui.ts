import {Command} from 'commander';
import {context} from '../context';
import {StakePool} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {lisuifyId, stakePoolId} from '../keys';
import {execute} from '../execute';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';

export const installDepositSui = (program: Command) => {
  program
    .command('deposit-sui')
    .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
    .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
    .argument('amount', 'Sui amount')
    .action(depositSui);
};

const depositSui = async (
  amount: string,
  {
    lisuify,
    poolId,
  }: {
    lisuify: string;
    poolId: string;
  }
) => {
  const stakePool = await StakePool.load({
    provider: context.provider,
    lisuifyId: lisuify,
    id: poolId,
  });

  const txb = new TransactionBlock();
  stakePool.depositSui({
    // eslint-disable-next-line node/no-unsupported-features/es-builtins
    amount: BigInt(parseFloat(amount) * Math.pow(10, SUI_DECIMALS)),
    txb,
  });

  execute(txb);
};
