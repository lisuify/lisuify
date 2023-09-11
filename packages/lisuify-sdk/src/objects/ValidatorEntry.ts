/* eslint-disable node/no-unsupported-features/es-builtins */
export class ValidatorEntry {
  private constructor(
    public readonly validatorPoolId: string,
    public readonly isActive: boolean,
    public readonly lastUpdateEpoch: bigint,
    public readonly lastUpdateSuiBalance: bigint // public readonly stakeActivationEpochs
  ) {}

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static read(data: any) {
    return new ValidatorEntry(
      data.validator_pool_id,
      data.is_active,
      BigInt(data.last_update_epoch),
      BigInt(data.last_update_sui_balance)
      // stake_activation_epochs
    );
  }
}
