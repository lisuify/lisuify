import {Command} from 'commander';
import {installShowStakePool} from './showStakePool';
import {installAddValidator} from './addValidator';
import {installDepositStake} from './depositStake';
import {installSetStakingdValidator} from './setStakingValidator';
import {installUpdate} from './update';
import {installDepositSui} from './depositSui';
import {installWithdraw} from './withdraw';

export const installCommands = (program: Command) => {
  installShowStakePool(program);
  installAddValidator(program);
  installDepositStake(program);
  installSetStakingdValidator(program);
  installUpdate(program);
  installDepositSui(program);
  installWithdraw(program);
};
