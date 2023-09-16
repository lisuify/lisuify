import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';

export const installUpdate = (program: Command) => {
  program.command('update').action(update);
};

const update = async () => {
  const state = await context.provider.getLatestSuiSystemState();
  // eslint-disable-next-line node/no-unsupported-features/es-builtins
  if (BigInt(state.epoch) === context.stakePool.lastUpdateEpoch) {
    return;
  }
  const txb = new TransactionBlock();
  context.stakePool.update({
    // provider: context.provider,
    txb,
  });

  await execute(txb);
};
