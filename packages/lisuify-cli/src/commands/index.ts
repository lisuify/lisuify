import {Command} from 'commander';
import {installShowStakePool} from './showStakePool';
import {installAddValidator} from './addValidator';
import {installDepositStake} from './depositStake';
import {installSetStakingdValidator} from './setStakingValidator';
import {installUpdate} from './update';

export const installCommands = (program: Command) => {
  installShowStakePool(program);
  installAddValidator(program);
  installDepositStake(program);
  installSetStakingdValidator(program);
  installUpdate(program);
};
