/* eslint-disable node/no-unsupported-features/es-builtins */
import {Command} from 'commander';
import {context} from '../context';
import {StakePool} from '@lisuify/sdk';
import {SUI_DECIMALS} from '@mysten/sui.js/utils';
import {stakePoolId} from '../keys';

export const installShowStakePool = (program: Command) => {
  program
    .command('show-sp')
    .option('--id <address>', 'Stake pool object address', stakePoolId)
    .action(showStakePool);
};

const showStakePool = async ({id}: {id: string}) => {
  const stakePool = await StakePool.load({
    provider: context.provider,
    lisuifyId: '',
    id,
  });

  console.log(`Stake pool ${stakePool.id}`);
  console.log(`  Admin cap: ${stakePool.adminCapId}`);
  console.log(`  Valdiator manager cap: ${stakePool.validatorManagerCapId}`);
  console.log(
    `  Token supply: ${
      stakePool.tokenSupply / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(`  Fees: ${stakePool.fees / BigInt(Math.pow(10, SUI_DECIMALS))}`);
  console.log(`  Fresh deposit fee: ${stakePool.freshDepositFeeBpc / 10000}%`);
  console.log(`  Withdraw fee: ${stakePool.withdrawFeeBpc / 10000}%`);
  console.log(`  Rewards fee: ${stakePool.rewardsFeeBpc / 10000}%`);
  console.log(`  Last update epoch: ${stakePool.lastUpdateEpoch}`);
  console.log(
    `  Last update sui balance: ${
      stakePool.lastUpdateSuiBalance / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(
    `  Last update token supply: ${
      stakePool.lastUpdateTokenSupply / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(
    `  Current sui balance: ${
      stakePool.currentSuiBalance / BigInt(Math.pow(10, SUI_DECIMALS))
    }`
  );
  console.log(`  Staking validator: ${stakePool.stakingValidator}`);
  console.log(
    `  Reserve: ${stakePool.reserve / BigInt(Math.pow(10, SUI_DECIMALS))}`
  );
};
