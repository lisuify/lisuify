/* eslint-disable node/no-unsupported-features/es-builtins */
export class StakePoolUpdate {
  private constructor(
    public readonly pendingSuiBalance: bigint,
    public readonly updatingEpoch: bigint,
    public readonly updatedValidators: bigint
  ) {}

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  static read(data: any) {
    return new StakePoolUpdate(
      BigInt(data.pending_sui_balance),
      BigInt(data.updating_epoch),
      BigInt(data.updated_validators)
    );
  }
}
