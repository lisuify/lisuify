import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';

export const installAddValidator = (program: Command) => {
  program
    .command('add-validator')
    .option('--pool <id>', 'Validator pool id')
    .option('--address <id>', 'Address')
    .action(addValidator);
};

const addValidator = async ({
  pool,
  address,
}: {
  pool?: string;
  address?: string;
}) => {
  const txb = new TransactionBlock();
  const suiSystem =
    !pool || !address
      ? await context.provider.getLatestSuiSystemState()
      : undefined;
  context.stakePool.addValidator({
    validatorPool: pool,
    address,
    suiSystem,
    txb,
  });

  await execute(txb);
};
