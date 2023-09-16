import {Command} from 'commander';
import {context} from '../context';
import {requestSuiFromFaucetV1, getFaucetHost} from '@mysten/sui.js/faucet';

export const installAirdrop = (program: Command) => {
  program.command('airdrop').action(airdrop);
};

const airdrop = async () => {
  const r = await requestSuiFromFaucetV1({
    host: getFaucetHost('testnet'), // todo
    recipient: context.wallet.getPublicKey().toSuiAddress(),
  });
  console.log(r);
};
