/* eslint-disable node/no-unsupported-features/es-builtins */
import {Command} from 'commander';
import {context} from '../context';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';

export const installShowStakePool = (program: Command) => {
  program.command('show-sp').action(showStakePool);
};

const showStakePool = async () => {
  console.log(`Stake pool ${context.stakePool.id}`);
  console.log(`  Admin cap: ${context.stakePool.adminCapId}`);
  console.log(
    `  Valdiator manager cap: ${context.stakePool.validatorManagerCapId}`
  );
  console.log(
    `  Token supply: ${
      context.stakePool.tokenSupply / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(
    `  Fees: ${context.stakePool.fees / BigInt(Math.pow(10, SUI_DECIMALS))}`
  );
  console.log(
    `  Fresh deposit fee: ${context.stakePool.freshDepositFeeBpc / 10000}%`
  );
  console.log(`  Withdraw fee: ${context.stakePool.withdrawFeeBpc / 10000}%`);
  console.log(`  Rewards fee: ${context.stakePool.rewardsFeeBpc / 10000}%`);
  console.log(`  Last update epoch: ${context.stakePool.lastUpdateEpoch}`);
  console.log(
    `  Last update sui balance: ${
      context.stakePool.lastUpdateSuiBalance /
      BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(
    `  Last update token supply: ${
      context.stakePool.lastUpdateTokenSupply /
      BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(
    `  Current sui balance: ${
      context.stakePool.currentSuiBalance / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(`  Staking validator: ${context.stakePool.stakingValidator}`);
  console.log(
    `  Reserve: ${
      context.stakePool.reserve / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log('  Validators:');
  for (const v of context.stakePool.validators) {
    console.log(`    Pool id: ${v.validatorPoolId}`);
  }
};
