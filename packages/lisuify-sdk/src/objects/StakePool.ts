/* eslint-disable node/no-unsupported-features/es-builtins */
import {
  CoinStruct,
  MoveValue,
  SuiClient,
  SuiSystemStateSummary,
} from '@mysten/sui.js/client';
import {TransactionBlock} from '@mysten/sui.js/transactions';
import {
  addValidator,
  depositStake,
  setStakingValidator,
} from '../transactionBuilder';
import {ValidatorEntry} from './ValidatorEntry';
import {StakePoolUpdate} from './StakePoolUpdate';
import {depositSui} from '../transactionBuilder/depositSui';
import {withdraw} from '../transactionBuilder/withdraw';
import {update} from '../transactionBuilder/update';

export class StakePool {
  private constructor(
    public readonly lisuifyId: string,
    public readonly originalLisuifyId: string,
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
    private _update: StakePoolUpdate | null,
    private _stakingValidator: string | null,
    private _validators: ValidatorEntry[],
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
  get validators() {
    return this._validators;
  }
  get reserve() {
    return this._reserve;
  }
  get currentUpdate() {
    return this._update;
  }

  static async load({
    provider,
    lisuifyId,
    originalLisuifyId,
    id,
  }: {
    provider: SuiClient;
    lisuifyId: string;
    originalLisuifyId: string;
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
      object.data.content.type !==
      `${originalLisuifyId}::stake_pool::StakePool<${originalLisuifyId}::coin::COIN>`
    ) {
      throw new Error(`Unexpected object type ${object.data.content.type}`);
    }

    const data = object.data.content.fields as {
      [key: string]: MoveValue;
    };

    return new StakePool(
      lisuifyId,
      originalLisuifyId,
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
      BigInt(data.current_sui_balance as string),
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (data.update as any) && StakePoolUpdate.read((data.update as any).fields),
      data.staking_validator as string | null,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (data.validators as {fields: any}[]).map(({fields}) =>
        ValidatorEntry.read(fields)
      ),
      BigInt(data.reserve as string)
    );
  }

  addValidator({
    validatorPool,
    address,
    suiSystem,
    txb,
  }: {
    validatorPool?: string;
    address?: string;
    suiSystem?: SuiSystemStateSummary;
    txb: TransactionBlock;
  }) {
    const validators = [];
    if (!validatorPool || !address) {
      if (!suiSystem) {
        throw new Error('SuiSystem is required');
      }
      if (validatorPool) {
        const v = suiSystem.activeValidators.find(
          ({stakingPoolId}) => stakingPoolId === validatorPool
        );
        if (!v) {
          throw new Error(`Can not find validaror by pool id ${validatorPool}`);
        }
        validators.push({
          validatorPool: v.stakingPoolId,
          address: v.suiAddress,
        });
      }
      if (address) {
        const v = suiSystem.activeValidators.find(
          ({suiAddress}) => suiAddress === address
        );
        if (!v) {
          throw new Error(`Can not find validaror by address ${address}`);
        }
        validators.push({
          validatorPool: v.stakingPoolId,
          address: v.suiAddress,
        });
      }
      if (validators.length === 0) {
        validators.push(
          ...suiSystem.activeValidators.map(({stakingPoolId, suiAddress}) => ({
            validatorPool: stakingPoolId,
            address: suiAddress,
          }))
        );
      }
    } else {
      validators.push({
        validatorPool,
        address,
      });
    }

    for (const {validatorPool, address} of validators) {
      addValidator({
        lisuifyId: this.lisuifyId,
        poolId: this.id,
        validatorPool,
        address,
        cap: this.validatorManagerCapId,
        txb,
      });
    }
  }

  depositStake({stake, txb}: {stake: string; txb: TransactionBlock}) {
    depositStake({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      stake,
      txb,
    });
  }

  depositSui({amount, txb}: {amount: bigint; txb: TransactionBlock}) {
    const coin = txb.splitCoins(txb.gas, [txb.pure(amount)]);
    depositSui({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      sui: coin,
      txb,
    });
  }

  withdraw({
    coins, // must be liSUI
    amount,
    txb,
  }: {
    coins: CoinStruct[];
    amount: bigint;
    txb: TransactionBlock;
  }) {
    if (coins.length === 0) {
      throw new Error('No coins');
    }
    const [primaryCoin, ...mergeCoins] = coins;
    const primaryCoinInput = txb.object(primaryCoin.coinObjectId);
    if (mergeCoins.length > 0) {
      // TODO: This could just merge a subset of coins that meet the balance requirements instead of all of them.
      txb.mergeCoins(
        primaryCoinInput,
        mergeCoins.map(coin => txb.object(coin.coinObjectId))
      );
    }
    const coin = txb.splitCoins(primaryCoinInput, [txb.pure(amount)]);
    withdraw({
      lisuifyId: this.lisuifyId,
      poolId: this.id,
      token: coin,
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

  async update({txb}: {txb: TransactionBlock}) {
    update({lisuifyId: this.lisuifyId, poolId: this.id, txb});
  }
}
