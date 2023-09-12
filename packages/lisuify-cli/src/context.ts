import {SuiClient} from '@mysten/sui.js/client';
import expandTilde = require('expand-tilde');
import * as YAML from 'yaml';
import * as fs from 'mz/fs';
import {Ed25519Keypair} from '@mysten/sui.js/keypairs/ed25519';
import {fromB64} from '@mysten/sui.js/utils';
import {PRIVATE_KEY_SIZE} from '@mysten/sui.js';
import {StakePool} from '@lisuify/sdk';

export interface Context {
  provider: SuiClient;
  wallet: Ed25519Keypair;
  dry: boolean;
  stakePool: StakePool;
}

export const context: Context = {} as Context;

export const setupContext = async ({
  config,
  env,
  wallet,
  dry = false,
  lisuifyId,
  originalLisuifyId,
  stakePoolId,
}: {
  config: string;
  env?: string;
  wallet?: string;
  dry?: boolean;
  lisuifyId: string;
  originalLisuifyId: string;
  stakePoolId: string;
}) => {
  const configData = YAML.parse(
    await fs.readFile(expandTilde(config), 'utf-8')
  );

  if (!env) {
    env = configData.active_env;
  }

  if (!wallet) {
    wallet = configData.active_address;
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const envConfig = configData.envs.find((e: any) => e.alias === env);

  context.provider = new SuiClient({url: envConfig.rpc});

  const keystore: string[] = JSON.parse(
    await fs.readFile(configData.keystore.File, 'utf-8')
  );

  for (const key of keystore) {
    const raw = fromB64(key);
    if (raw[0] !== 0 || raw.length !== PRIVATE_KEY_SIZE + 1) {
      throw new Error('invalid key');
    }
    const imported = Ed25519Keypair.fromSecretKey(raw.slice(1));
    if (imported.getPublicKey().toSuiAddress() === wallet) {
      context.wallet = imported;
      break;
    }
  }
  if (!context.wallet) {
    throw new Error('Unknown wallet address');
  }

  context.dry = dry;

  context.stakePool = await StakePool.load({
    provider: context.provider,
    id: stakePoolId,
    lisuifyId,
    originalLisuifyId,
  });
};
