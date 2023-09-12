import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';

export const installAddValidator = (program: Command) => {
  program
    .command('add-validator')
    .argument('validator', 'Validator pool id')
    .action(addValidator);
};

const addValidator = async (validator: string) => {
  const txb = new TransactionBlock();
  context.stakePool.addValidator({
    validatorPool: validator,
    txb,
  });

  await execute(txb);
};
