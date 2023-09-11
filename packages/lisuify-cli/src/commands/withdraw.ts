import {Command} from 'commander';
import {context} from '../context';
import {StakePool, getTokenCoins} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {lisuifyId, stakePoolId} from '../keys';
import {execute} from '../execute';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';

export const installWithdraw = (program: Command) => {
  program
    .command('withdraw')
    .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
    .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
    .argument('amount', 'Sui amount')
    .action(withdraw);
};

const withdraw = async (
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
  const coins = await getTokenCoins({
    provider: context.provider,
    lisuifyId: lisuify,
    owner: context.wallet.getPublicKey().toSuiAddress(),
  });

  const txb = new TransactionBlock();
  stakePool.withdraw({
    coins,
    // eslint-disable-next-line node/no-unsupported-features/es-builtins
    amount: BigInt(parseFloat(amount) * Math.pow(10, SUI_DECIMALS)),
    txb,
  });

  await execute(txb);
};
