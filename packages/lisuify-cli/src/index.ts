import {Command} from 'commander';
import {installCommands} from './commands';
import {setupContext} from './context';
import {lisuifyId, originalLisuifyId, stakePoolId} from './keys';

const program = new Command();

program
  .version('0.0.1')
  .allowExcessArguments(false)
  .option('--config <config>', 'Config', '~/.sui/sui_config/client.yaml')
  .option('--env <env>', 'Environment')
  .option('--wallet <address>', 'Wallet')
  .option('--dry', 'Do not run tx')
  .option('--lisuify <address>', 'Lisuify contact address', lisuifyId)
  .option(
    '--original-lisuify <address>',
    'Original lisuify contact address',
    originalLisuifyId
  )
  .option('--pool-id <address>', 'Stake pool object address', stakePoolId)
  .hook('preAction', async (command: Command) => {
    await setupContext({
      config: command.opts().config,
      env: command.opts().env,
      wallet: command.opts().wallet,
      dry: command.opts().dry,
      lisuifyId: command.opts().lisuify,
      originalLisuifyId: command.opts().originalLisuify,
      stakePoolId: command.opts().poolId,
    });
  });

installCommands(program);

program.parseAsync(process.argv);
