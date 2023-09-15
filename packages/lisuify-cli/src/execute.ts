import {TransactionBlock} from '@mysten/sui.js/transactions';
import {context} from './context';

export const execute = async (txb: TransactionBlock) => {
  txb.setGasBudget(200000000);
  txb.setSenderIfNotSet(context.wallet.getPublicKey().toSuiAddress());
  const txBytes = await txb.build({
    client: context.provider,
  });
  const s = await context.provider.dryRunTransactionBlock({
    transactionBlock: txBytes,
  });
  if (s.effects.status.status === 'failure') {
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
