import {Command} from 'commander';
import {context} from '../context';
import {getTokenCoins} from '@lisuify/sdk';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';

export const installWithdraw = (program: Command) => {
  program.command('withdraw').argument('amount', 'Sui amount').action(withdraw);
};

const withdraw = async (amount: string) => {
  const coins = await getTokenCoins({
    provider: context.provider,
    originalLisuifyId: context.stakePool.originalLisuifyId,
    owner: context.wallet.getPublicKey().toSuiAddress(),
  });

  const txb = new TransactionBlock();
  context.stakePool.withdraw({
    coins,
    // eslint-disable-next-line node/no-unsupported-features/es-builtins
    amount: BigInt(parseFloat(amount) * Math.pow(10, SUI_DECIMALS)),
    txb,
  });

  await execute(txb);
};
