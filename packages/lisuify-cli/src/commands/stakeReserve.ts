import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';

export const installStakeReserve = (program: Command) => {
  program
    .command('stake-reserve')
    .option('--validator <address>', 'Validator address')
    .action(stakeReserve);
};

const stakeReserve = async ({validator}: {validator?: string}) => {
  // eslint-disable-next-line node/no-unsupported-features/es-builtins
  if (context.stakePool.reserve < BigInt(1000000000)) {
    return;
  }
  const txb = new TransactionBlock();
  context.stakePool.stakeReserve({
    validatorAddress: validator,
    txb,
  });

  txb.setGasBudget(200000000);
  txb.setSenderIfNotSet(context.wallet.getPublicKey().toSuiAddress());
  const txBytes = await txb.build({
    client: context.provider,
  });
  const s = await context.provider.dryRunTransactionBlock({
    transactionBlock: txBytes,
  });
  if (s.effects.status.status === 'failure') {
    if (s.effects.status.error!.endsWith(' 2006) in command 0')) {
      return;
    }
    console.log(s.effects.status.error);
    throw new Error(s.effects.status.error);
  }

  if (context.dry) {
    return;
  }
  const r = await context.provider.signAndExecuteTransactionBlock({
    transactionBlock: txBytes,
    signer: context.wallet,
  });
  console.log(r);
};
