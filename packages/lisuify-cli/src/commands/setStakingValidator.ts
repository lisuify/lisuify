import {Command} from 'commander';
import {context} from '../context';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {execute} from '../execute';

export const installSetStakingdValidator = (program: Command) => {
  program
    .command('set-staking-validator')
    .argument('validator', 'Validator pool id')
    .action(setStakingValidator);
};

const setStakingValidator = async (validator: string) => {
  const txb = new TransactionBlock();
  context.stakePool.setStakingValidator({
    address: validator,
    txb,
  });

  await execute(txb);
};
