/* eslint-disable node/no-unsupported-features/es-builtins */
import {MoveValue, SuiClient} from '@mysten/sui.js/client';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {
  addValidator,
  depositStake,
  setStakingValidator,
} from '../transactionBuilder';

export class StakePool {
  private constructor(
    public readonly lisuifyId: string,
    public readonly id: string,
    private _adminCapId: string,
    private _validatorManagerCapId: string,
    private _tokenSupply: bigint,
    private _fees: bigint,
    private _freshDepositFeeBpc: number,
    private _withdrawFeeBpc: number,
    private _rewardsFeeBpc: number,
    private _lastUpdateEpoch: bigint,
    private _lastUpdateSuiBalance: bigint,
    private _lastUpdateTokenSupply: bigint,
    private _currentSuiBalance: bigint,
    private _stakingValidator: string | null,
    private _reserve: bigint
  ) {}

  get adminCapId() {
    return this._adminCapId;
  }
  get validatorManagerCapId() {
    return this._validatorManagerCapId;
  }
  get tokenSupply() {
    return this._tokenSupply;
  }
  get fees() {
    return this._fees;
  }
  get freshDepositFeeBpc() {
    return this._freshDepositFeeBpc;
  }
  get withdrawFeeBpc() {
    return this._withdrawFeeBpc;
  }
  get rewardsFeeBpc() {
    return this._rewardsFeeBpc;
  }
  get lastUpdateEpoch() {
    return this._lastUpdateEpoch;
  }
  get lastUpdateSuiBalance() {
    return this._lastUpdateSuiBalance;
  }
  get lastUpdateTokenSupply() {
    return this._lastUpdateTokenSupply;
  }
  get currentSuiBalance() {
    return this._currentSuiBalance;
  }
  get stakingValidator() {
    return this._stakingValidator;
  }
  get reserve() {
    return this._reserve;
  }

  static async load({
    provider,
    lisuifyId,
    id,
  }: {
    provider: SuiClient;
    lisuifyId: string;
    id: string;
  }) {
    const object = await provider.getObject({
      id,
      options: {
        showContent: true,
      },
    });

    if (!object.data) {
      throw new Error(JSON.stringify(object.error));
    }

    if (object.data.content?.dataType !== 'moveObject') {
      throw new Error('Expected object not package');
    }

    if (
      !/^0x[0-9a-fA-F]+::stake_pool::StakePool<0x[0-9a-fA-F]+::coin::COIN>$/.test(
        object.data.content.type
      )
    ) {
      throw new Error(`Unexpected object type ${object.data.content.type}`);
    }

    const data = object.data.content.fields as {
      [key: string]: MoveValue;
    };

    return new StakePool(
      lisuifyId,
      id,
      data.admin_cap_id as string,
      data.validator_manager_cap_id as string,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      BigInt((data.treasury as any).fields.total_supply.fields.value),
      BigInt(data.fees as string),
      data.fresh_deposit_fee_bpc as number,
      data.withdraw_fee_bpc as number,
      data.rewards_fee_bpc as number,
      BigInt(data.last_update_epoch as string),
      BigInt(data.last_update_sui_balance as string),
      BigInt(data.last_update_token_supply as string),
      BigInt(data.curret_sui_balance as string),
      data.staking_validator as string | null,
      BigInt(data.reserve as string)
    );
  }

  addValidator({
    validatorPool,
    txb,
  }: {
    validatorPool: string;
    txb: TransactionBlock;
  }) {
    addValidator({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      validatorPool,
      cap: this.validatorManagerCapId,
      txb,
    });
  }

  depositStake({stake, txb}: {stake: string; txb: TransactionBlock}) {
    depositStake({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      stake,
      txb,
    });
  }

  setStakingValidator({
    address,
    txb,
  }: {
    address: string | null;
    txb: TransactionBlock;
  }) {
    setStakingValidator({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      address,
      cap: this.validatorManagerCapId,
      txb,
    });
  }
}
