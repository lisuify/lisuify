import {Command} from 'commander';
import {installCommands} from './commands';
import {setupContext} from './context';

const program = new Command();

program
  .version('0.0.1')
  .allowExcessArguments(false)
  .option('--config <config>', 'Config', '~/.sui/sui_config/client.yaml')
  .option('--env <env>', 'Environment')
  .option('--wallet <address>', 'Wallet')
  .option('--dry', 'Do not run tx')
  .hook('preAction', async (command: Command) => {
    await setupContext({
      config: command.opts().config,
      env: command.opts().env,
      wallet: command.opts().wallet,
      dry: command.opts().dry,
    });
  });

installCommands(program);

program.parseAsync(process.argv);
