import {Command} from 'commander';
import {context} from '../context';
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
  const suiSystem =
    !pool || !address
      ? await context.provider.getLatestSuiSystemState()
      : undefined;
  for (const txb of context.stakePool.addValidator({
    validatorPool: pool,
    address,
    suiSystem,
  })) {
    await execute(txb);
  }
};
