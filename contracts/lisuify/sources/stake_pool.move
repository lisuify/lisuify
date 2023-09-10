module lisuify::stake_pool {
    use sui::object::{Self, UID, ID};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::option::{Self, Option};
    use lisuify::validator_entry::{Self, ValidatorEntry};
    use std::vector;
    use sui_system::staking_pool::{Self, StakedSui};
    use sui_system::sui_system::{Self, SuiSystemState};
    use sui::pay;

    friend lisuify::coin;

    const MAX_BPC: u32 = 1000000;
    const EOutdated: u64 = 3;
    const EValidatorAlreadyExists: u64 = 5;
    const EValidatorDoesNotExist: u64 = 6;
    const EWrongValidatorManagerCap: u64 = 7;
    const EAlreadyUpdated: u64 = 8;
    const ETooEarlyToUpdate: u64 = 9;
    const EUpdateIsAlreadyRunning: u64 = 10;
    const ENotUpdating: u64 = 11;
    const ESlashed: u64 = 12;

    struct StakePoolUpdate has store, drop {
        pending_sui_balance: u64,
        updating_epoch: u64,
        updated_validators: u64,
    }

    struct StakePool<phantom C> has key {
        id: UID,
        admin_cap_id: ID,
        validator_manager_cap_id: ID,
        treasury: TreasuryCap<C>,
        fees: Balance<C>,
        fresh_deposit_fee_bpc: u32, // replaces the next epoch rate prediction
        withdraw_fee_bpc: u32,
        rewards_fee_bpc: u32,
        last_update_epoch: u64,
        last_update_sui_balance: u64,
        last_update_token_supply: u64,
        curret_sui_balance: u64,
        update: Option<StakePoolUpdate>,
        staking_validator: Option<address>,
        validators: vector<ValidatorEntry<C>>,
        reserve: Balance<SUI>,
    }

    struct AdminCap<phantom C> has key, store {
        id: UID,
    }

    struct ValidatorManagerCap<phantom C> has key, store {
        id: UID,
    }

    public(friend) fun new<C>(
        treasury: TreasuryCap<C>,
        ctx: &mut TxContext
    ) : (AdminCap<C>, ValidatorManagerCap<C>)
    {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };

        let validator_manager_cap = ValidatorManagerCap {
            id: object::new(ctx),
        };
        
        let stake_pool = StakePool {
            id: object::new(ctx),
            admin_cap_id: object::id(&admin_cap),
            validator_manager_cap_id: object::id(&validator_manager_cap),
            treasury,
            fees: balance::zero(),
            fresh_deposit_fee_bpc: 100,
            withdraw_fee_bpc: 100,
            rewards_fee_bpc: 50000,
            last_update_epoch: tx_context::epoch(ctx),
            last_update_sui_balance: 0,
            last_update_token_supply: 0,
            curret_sui_balance: 0,
            update: option::none(),
            staking_validator: option::none(),
            validators: vector::empty(),
            reserve: balance::zero(),
        };
        
        transfer::share_object(stake_pool);

        (admin_cap, validator_manager_cap)
    }

    public fun is_updated<C>(
        self: &mut StakePool<C>,
        ctx: &TxContext,
    ): bool {
        let epoch = tx_context::epoch(ctx);
        epoch == self.last_update_epoch
    }

    public fun validator_index<C>(
        self: &StakePool<C>,
        validator_pool_id: ID,
    ) : Option<u64> 
    {
        let i = 0;
        let validator_count = vector::length(&self.validators);
        while (i < validator_count) {
            let validator = vector::borrow(&self.validators, i);
            if (validator_entry::validator_pool_id(validator) == validator_pool_id) {
                return option::some(i)
            };
            i = i + 1;
        };
        option::none()
    }

    public entry fun add_validator<C>(
        self: &mut StakePool<C>,
        validator_pool_id: ID,
        cap: &ValidatorManagerCap<C>,
        ctx: &mut TxContext,
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        assert!(
            option::is_none(&validator_index(self, validator_pool_id)),
            EValidatorAlreadyExists
        );
        let validator_entry = validator_entry::new(
            object::id(self),
            validator_pool_id,
            ctx
        );
        vector::push_back(&mut self.validators, validator_entry);
    }

    public entry fun remove_validator<C>(
        self: &mut StakePool<C>,
        validator_pool_id: ID,
        cap: &ValidatorManagerCap<C>
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        let i = validator_index(self, validator_pool_id);
        assert!(option::is_some(&i), EValidatorDoesNotExist);
        let i = option::destroy_some(i);
        let validator = vector::remove(&mut self.validators, i);
        validator_entry::destroy_empty(validator);
        // sync update
        if (option::is_some(&self.update)) {
            let update = option::borrow_mut(&mut self.update);
            if (i < update.updated_validators) {
                update.updated_validators = update.updated_validators - 1;
            }
        };
    }

    public entry fun start_update<C>(
        self: &mut StakePool<C>,
        ctx: &TxContext,
    ) {
        let epoch = tx_context::epoch(ctx);
        assert!(epoch > self.last_update_epoch, ETooEarlyToUpdate);
        if (option::is_some(&self.update)) {
            let update = option::borrow(&mut self.update);
            assert!(epoch > update.updating_epoch, EUpdateIsAlreadyRunning);
        };
        option::swap(&mut self.update, StakePoolUpdate {
            pending_sui_balance: 0,
            updating_epoch: epoch,
            updated_validators: 0,
        });
    }

    public entry fun update_validator<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        ctx: &TxContext,
    ) {
        let epoch = tx_context::epoch(ctx);
        if(option::is_none(&self.update)
            || epoch != option::borrow(&self.update).updating_epoch
        ) {
            start_update(self, ctx);
        };
        let update = option::borrow_mut(&mut self.update);
        let validator_count = vector::length(&self.validators);
        assert!(
            update.updated_validators < validator_count,
            EAlreadyUpdated
        );
        let validator = vector::borrow_mut(
            &mut self.validators,
            update.updated_validators
        );
        validator_entry::update(
            validator,
            sui_system,
            validator_pool_id,
            ctx,
        );
        update.pending_sui_balance = update.pending_sui_balance
            + validator_entry::last_update_sui_balance(validator);
        update.updated_validators = update.updated_validators + 1;
    }

    public entry fun finalize_update<C>(
        self: &mut StakePool<C>
    ) {
        assert!(option::is_some(&self.update), ENotUpdating);
        let update = option::extract(&mut self.update);
        assert!(
            update.pending_sui_balance >= self.curret_sui_balance,
            ESlashed
        );
        let rewards = update.pending_sui_balance - self.curret_sui_balance;
        let fee = (((rewards as u128)
            * (self.rewards_fee_bpc as u128)
            / (MAX_BPC as u128)) as u64);
        let token_fee = get_token_amount(self, fee);
        let fee_balance = coin::mint_balance(&mut self.treasury, token_fee);
        balance::join(&mut self.fees, fee_balance);

        self.last_update_epoch = update.updating_epoch;
        self.last_update_sui_balance = update.pending_sui_balance;
        self.last_update_token_supply = coin::total_supply(&self.treasury);
        self.curret_sui_balance = update.pending_sui_balance;
    }

    fun deposit_stake_internal<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &TxContext
    ): (u64, u64) {
        assert!(is_updated(self, ctx), EOutdated); // requires updated state for up to date liSUI price
        let validator_index = validator_index(self, staking_pool::pool_id(&stake));
        assert!(option::is_some(&validator_index), EValidatorDoesNotExist);
        let validator = vector::borrow_mut(
            &mut self.validators,
            option::destroy_some(validator_index)
        );
        let stake_activation_epoch = staking_pool::stake_activation_epoch(&stake);
        let stake_balance = validator_entry::add_stake(
            validator,
            sui_system,
            stake,
            ctx
        );
        (stake_balance, stake_activation_epoch)
    }

    public fun deposit_stake_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &TxContext,
    ): Balance<C> {
        let (stake_balance, stake_activation_epoch) = deposit_stake_internal(
            self,
            sui_system,
            stake,
            ctx
        );
        self.curret_sui_balance = self.curret_sui_balance + stake_balance;

        let token_amount = get_token_amount(self, stake_balance);
        // for fresh stakes
        let epoch = tx_context::epoch(ctx);
        if (stake_activation_epoch > epoch) {
            token_amount = (((token_amount as u128)
                * ((MAX_BPC - self.fresh_deposit_fee_bpc) as u128)
                / (MAX_BPC as u128)) as u64);
        };
        coin::mint_balance(&mut self.treasury, token_amount)
    }

    public entry fun deposit_stake<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &mut TxContext,
    ) {
        let balance = deposit_stake_non_entry(
            self,
            sui_system,
            stake,
            ctx
        );
        pay::keep(
            coin::from_balance(balance, ctx),
            ctx
        );
    }

    public fun deposit_sui_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ): Balance<C> {
        if (option::is_some(&self.staking_validator)) {
            let stake = sui_system::request_add_stake_non_entry(
                sui_system,
                sui,
                *option::borrow(&self.staking_validator),
                ctx
            );
            deposit_stake_non_entry(
                self,
                sui_system,
                stake,
                ctx
            )
        } else {
            assert!(is_updated(self, ctx), EOutdated);
            self.curret_sui_balance = self.curret_sui_balance + coin::value(&sui);
            let token_amount = get_token_amount(self, coin::value(&sui));
            token_amount = (((token_amount as u128)
                * ((MAX_BPC - self.fresh_deposit_fee_bpc) as u128)
                / (MAX_BPC as u128)) as u64);
            coin::put(&mut self.reserve, sui);
            coin::mint_balance(&mut self.treasury, token_amount)
        }
    }

    public entry fun deposit_sui<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let balance = deposit_sui_non_entry(
            self,
            sui_system,
            sui,
            ctx
        );
        pay::keep(
            coin::from_balance(balance, ctx),
            ctx
        );
    }

    public entry fun stake_reserve<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_address: address,
        amount: u64,
        cap: &ValidatorManagerCap<C>,
        ctx: &mut TxContext,
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );

        let stake = sui_system::request_add_stake_non_entry(
            sui_system,
            coin::take(&mut self.reserve, amount, ctx),
            validator_address,
            ctx
        );
        let (_, _) = deposit_stake_internal(
            self,
            sui_system,
            stake,
            ctx
        );
    }

    public fun get_sui_amount<C>(self: &StakePool<C>, token_amount: u64): u64 {
        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (self.last_update_sui_balance == 0 || self.last_update_token_supply == 0) {
            return token_amount
        };
        let res = (self.last_update_sui_balance as u128)
                * (token_amount as u128)
                / (self.last_update_token_supply as u128);
        (res as u64)
    }

    public fun get_token_amount<C>(self: &StakePool<C>, sui_amount: u64): u64 {
        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (self.last_update_sui_balance == 0 || self.last_update_token_supply == 0) {
            return sui_amount
        };
        let res = (self.last_update_token_supply as u128)
                * (sui_amount as u128)
                / (self.last_update_sui_balance as u128);
        (res as u64)
    }

    public fun staking_validator<C>(self: &StakePool<C>): Option<address> {
        self.staking_validator
    }

    public fun set_staking_validator<C>(
        self: &mut StakePool<C>,
        v: Option<address>,
        cap: &ValidatorManagerCap<C>,
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        self.staking_validator = v;
    }
}