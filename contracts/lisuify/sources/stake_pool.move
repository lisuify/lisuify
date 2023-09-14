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
    use sui::math;
    use sui::clock::{Self, Clock};
    use sui::event;

    friend lisuify::coin;

    const MAX_BPC: u32 = 1000000;
    const ONE_MINUTE_MS: u64 = 60000;
    const ONE_DAY_MS: u64 = 86400000;

    const EOutdated: u64 = 2000;
    const EValidatorAlreadyExists: u64 = 2001;
    const EValidatorDoesNotExist: u64 = 2002;
    const EWrongValidatorManagerCap: u64 = 2003;
    const EAlreadyUpdated: u64 = 2004;
    const ESlashed: u64 = 2005;
    const EWrongValidatorAddress: u64 = 2006;
    const ETooEarlyToStakeReserve: u64 = 2007;
    const EWrongAdminCap: u64 = 2008;
    const ENotEnoughSuiToWithdraw: u64 = 2009;
    const EForcedUstakeCapped: u64 = 2010;

    /// StakedSui objects cannot be split to below this amount.
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI

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
        keeping_reserve_ms: u64,
        max_forced_unstake_bpc: u32,
        last_update_epoch: u64,
        last_update_sui_balance: u64,
        last_update_token_supply: u64,
        current_sui_balance: u64,
        current_forced_ustake: u64,
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
            keeping_reserve_ms: ONE_DAY_MS - 10 * ONE_MINUTE_MS,
            max_forced_unstake_bpc: 100000,
            last_update_epoch: tx_context::epoch(ctx),
            last_update_sui_balance: 0,
            last_update_token_supply: 0,
            current_sui_balance: 0,
            current_forced_ustake: 0,
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

    struct ValidatorAdded has copy, drop {
        stake_pool_id: ID,
        validator_pool_id: ID,
        new_count: u64
    }

    public entry fun add_validator<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        validator_address: address,
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
            sui_system,
            object::id(self),
            validator_pool_id,
            validator_address,
            ctx
        );
        vector::push_back(&mut self.validators, validator_entry);
        event::emit(ValidatorAdded {
            stake_pool_id: object::id(self),
            validator_pool_id,
            new_count: vector::length(&self.validators)
        })
    }

    struct ValidatorActiveChanged has copy, drop {
        stake_pool_id: ID,
        validator_pool_id: ID,
        is_active: bool,
    }

    public entry fun set_validator_active<C>(
        self: &mut StakePool<C>,
        validator_pool_id: ID,
        is_active: bool,
        cap: &ValidatorManagerCap<C>
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        let i = validator_index(self, validator_pool_id);
        assert!(option::is_some(&i), EValidatorDoesNotExist);
        let i = option::destroy_some(i);
        let validator = vector::borrow_mut(&mut self.validators, i);
        if (validator_entry::is_active(validator) == is_active) {
            return
        };
        validator_entry::set_is_active(validator, is_active);
        event::emit(ValidatorActiveChanged {
            stake_pool_id: object::id(self),
            validator_pool_id,
            is_active
        })
    }

    struct ValidatorRemoved has copy, drop {
        stake_pool_id: ID,
        validator_pool_id: ID,
        new_count: u64
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
        event::emit(ValidatorRemoved {
            stake_pool_id: object::id(self),
            validator_pool_id,
            new_count: vector::length(&self.validators),
        })
    }

    struct UpdateStarted has copy, drop {
        stake_pool_id: ID,
        epoch: u64
    }

    fun start_update<C>(
        self: &mut StakePool<C>,
        ctx: &TxContext,
    ) {
        let epoch = tx_context::epoch(ctx);
        option::swap_or_fill(&mut self.update, StakePoolUpdate {
            pending_sui_balance: balance::value(&self.reserve),
            updating_epoch: epoch,
            updated_validators: 0,
        });
        event::emit(UpdateStarted {
            stake_pool_id: object::id(self),
            epoch,
        })
    }

    struct ValidatorUpdated has copy, drop {
        stake_pool_id: ID,
        epoch: u64,
        validator_pool_id: ID,
        validator_index: u64,
        validator_sui_balance: u64,
    }

    fun update_validator<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        ctx: &mut TxContext,
    ) {
        let stake_pool_id = object::id(self);
        let update = option::borrow_mut(&mut self.update);

        let validator = vector::borrow_mut(
            &mut self.validators,
            update.updated_validators
        );
        
        let validator_sui_balance = validator_entry::update(
            validator,
            sui_system,
            ctx,
        );
        update.pending_sui_balance = update.pending_sui_balance + validator_sui_balance;
        update.updated_validators = update.updated_validators + 1;
        event::emit(ValidatorUpdated {
            stake_pool_id,
            epoch: update.updating_epoch,
            validator_pool_id: validator_entry::validator_pool_id(validator),
            validator_index: update.updated_validators - 1,
            validator_sui_balance
        })
    }

    struct UpdateFinalized has copy, drop {
        stake_pool_id: ID,
        epoch: u64,
        rewards: u64,
        fees_collected: u64,
        old_sui_balance: u64,
        old_token_supply: u64,
        new_sui_balance: u64,
        new_token_supply: u64,
    }

    fun finalize_update<C>(
        self: &mut StakePool<C>
    ) {
        let update = option::extract(&mut self.update);
        assert!(
            update.pending_sui_balance >= self.current_sui_balance,
            ESlashed
        );
        let old_sui_balance = self.last_update_sui_balance;
        let old_token_supply = self.last_update_token_supply;

        let rewards = update.pending_sui_balance - self.current_sui_balance;
        let fee = (((rewards as u128)
            * (self.rewards_fee_bpc as u128)
            / (MAX_BPC as u128)) as u64);
        let token_fee = get_token_amount(self, fee);
        let fee_balance = coin::mint_balance(&mut self.treasury, token_fee);
        balance::join(&mut self.fees, fee_balance);

        self.last_update_epoch = update.updating_epoch;
        self.last_update_sui_balance = update.pending_sui_balance;
        self.last_update_token_supply = coin::total_supply(&self.treasury);
        self.current_sui_balance = update.pending_sui_balance;
        self.current_forced_ustake = 0;

        event::emit(UpdateFinalized {
            stake_pool_id: object::id(self),
            epoch: update.updating_epoch,
            rewards,
            fees_collected: token_fee,
            old_sui_balance,
            old_token_supply,
            new_sui_balance: self.last_update_sui_balance,
            new_token_supply: self.last_update_token_supply
        })
    }

    public entry fun update<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        max_validators: u64,
        ctx: &mut TxContext,
    ) {
        let epoch = tx_context::epoch(ctx);
        assert!(epoch > self.last_update_epoch, EAlreadyUpdated);
        if (option::is_none(&self.update)
            || epoch != option::borrow(&self.update).updating_epoch
        ) {
            start_update(self, ctx);
        };
        let validator_count = vector::length(&self.validators);
        while (
            option::borrow(&self.update).updated_validators < validator_count &&
            max_validators > 0
        ) {
            update_validator(
                self,
                sui_system,
                ctx,
            );
            max_validators = max_validators - 1;
        };
        if (option::borrow(&self.update).updated_validators == validator_count) {
            finalize_update(self);
        }
    }

    fun stake_validator_entry<C>(
        self: &mut StakePool<C>,
        stake: &StakedSui,
    ): &mut ValidatorEntry<C> {
        let validator_pool_id = staking_pool::pool_id(stake);
        let validator_index = validator_index(self, validator_pool_id);
        assert!(option::is_some(&validator_index), EValidatorDoesNotExist);
        vector::borrow_mut(
            &mut self.validators,
            option::destroy_some(validator_index)
        )
    }

    struct StakeDeposited has copy, drop {
        stake_pool_id: ID,
        validator_pool_id: ID,
        stake_activation_epoch: u64,
        principal: u64,
        stake_balance: u64,
        is_fresh: bool,
        token_mint: u64,
        new_current_sui_balance: u64,
        fresh_deposit_fee_bpc: u32,
        last_update_sui_balance: u64,
        last_update_token_supply: u64,
    }

    public fun deposit_stake_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &mut TxContext,
    ): Balance<C> {
        assert!(is_updated(self, ctx), EOutdated); // requires updated state for up to date liSUI price
        let validator_pool_id = staking_pool::pool_id(&stake);
        let stake_activation_epoch = staking_pool::stake_activation_epoch(&stake);
        let validator = stake_validator_entry(self, &stake);
        let principal = staking_pool::staked_sui_amount(&stake);
        let (stake_balance, is_fresh) = validator_entry::add_stake(
            validator,
            sui_system,
            stake,
            ctx
        );
        self.current_sui_balance = self.current_sui_balance + stake_balance;

        let token_mint = get_token_amount(self, stake_balance);
        if (is_fresh) {
            token_mint = (((token_mint as u128)
                * ((MAX_BPC - self.fresh_deposit_fee_bpc) as u128)
                    / (MAX_BPC as u128)) as u64);
        };
        event::emit(StakeDeposited {
            stake_pool_id: object::id(self),
            validator_pool_id,
            stake_activation_epoch,
            principal,
            stake_balance,
            is_fresh,
            token_mint,
            new_current_sui_balance: self.current_sui_balance,
            fresh_deposit_fee_bpc: self.fresh_deposit_fee_bpc,
            last_update_sui_balance: self.last_update_sui_balance,
            last_update_token_supply: self.last_update_token_supply,
        });
        coin::mint_balance(
            &mut self.treasury,
            token_mint
        )
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

    struct SuiDeposited has copy, drop {
        stake_pool_id: ID,
        sui_deposited: u64,
        token_mint: u64,
        new_current_sui_balance: u64,
        fresh_deposit_fee_bpc: u32,
        last_update_sui_balance: u64,
        last_update_token_supply: u64,
    }

    public fun deposit_sui_internal<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        coin::put(&mut self.reserve, sui);

        let reserve_balance = balance::value(&self.reserve);
        if (reserve_balance >= MIN_STAKING_THRESHOLD
            && option::is_some(&self.staking_validator)
            && is_staking_reserve_time(self, clock, ctx)
        ) {
            let validator_address = *option::borrow(&self.staking_validator);
            stake_reserve_internal(
                self,
                sui_system,
                validator_address,
                reserve_balance,
                ctx
            )
        };
    }

    public fun deposit_sui_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ): Balance<C> {
        assert!(is_updated(self, ctx), EOutdated);
        let sui_deposited = coin::value(&sui);
        self.current_sui_balance = self.current_sui_balance + sui_deposited;
        let token_mint = get_token_amount(self, sui_deposited);
        token_mint = (((token_mint as u128)
            * ((MAX_BPC - self.fresh_deposit_fee_bpc) as u128)
            / (MAX_BPC as u128)) as u64);
        
        event::emit(SuiDeposited {
            stake_pool_id: object::id(self),
            sui_deposited,
            token_mint,
            new_current_sui_balance: self.current_sui_balance,
            fresh_deposit_fee_bpc: self.fresh_deposit_fee_bpc,
            last_update_sui_balance: self.last_update_sui_balance,
            last_update_token_supply: self.last_update_token_supply,
        });

        deposit_sui_internal(
            self,
            sui_system,
            clock,
            sui,
            ctx
        );
        coin::mint_balance(&mut self.treasury, token_mint)
    }

    public entry fun deposit_sui<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        sui: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let balance = deposit_sui_non_entry(
            self,
            sui_system,
            clock,
            sui,
            ctx
        );
        pay::keep(
            coin::from_balance(balance, ctx),
            ctx
        );
    }

    fun withdraw_sui_internal<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        sui_amount: u64,
        ctx: &mut TxContext,
    ): (Balance<SUI>, u64) {
        let from_reserve = math::min(sui_amount, balance::value(&self.reserve));
        let result = balance::split(
            &mut self.reserve,
            from_reserve
        );
        let fresh_part = from_reserve;

        let i = 0;
        let count = vector::length(&self.validators);
        while (i < count && balance::value(&result) < sui_amount) {
            let validator = vector::borrow_mut(&mut self.validators, i);
            let sui = validator_entry::withdraw(
                validator,
                sui_system,
                sui_amount - balance::value(&result),
                ctx,
            );
            balance::join(&mut result, sui);
            i = i + 1;
        };

        let withdrawn = balance::value(&result);
        if (withdrawn > sui_amount) {
            // return the rest to the reserve
            balance::join(
                &mut self.reserve,
                balance::split(
                    &mut result,
                    withdrawn - sui_amount
                )
            );
        };
        (result, fresh_part)
    }

    fun withdraw_fresh_stakes<C>(
        self: &mut StakePool<C>,
        sui_amount: u64,
        ctx: &mut TxContext,
    ): (vector<StakedSui>, u64)
    {
        let result = vector::empty();
        let withdrawn = 0;
        let i = 0;
        let count = vector::length(&self.validators);
        while (i < count && withdrawn + MIN_STAKING_THRESHOLD <= sui_amount) {
            let validator = vector::borrow_mut(&mut self.validators, i);
            let staked = validator_entry::withdraw_fresh(
                validator,
                sui_amount - withdrawn,
                ctx,
            );
            if (option::is_some(&staked)) {
                let stake = option::destroy_some(staked);
                let stake_balance = staking_pool::staked_sui_amount(&stake);
                vector::push_back(&mut result, stake);
                withdrawn = withdrawn + stake_balance;
            } else {
                option::destroy_none(staked)
            };
            i = i + 1;
        };
        (result, withdrawn)
    }

    struct Withdrawn has copy, drop {
        stake_pool_id: ID,
        token_burnt: u64,
        sui_withdrawn: u64,
        staked_sui_withdrawn: u64,
        token_returned: u64,
        fees_collected: u64,
        new_current_sui_balance: u64,
        fresh_deposit_fee_bpc: u32,
        withdraw_fee_bpc: u32,
        last_update_sui_balance: u64,
        last_update_token_supply: u64,
    }

    public fun withdraw_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        token_balance: Balance<C>,
        ctx: &mut TxContext,
    ): (Balance<SUI>, vector<StakedSui>, Balance<C>) {
        assert!(is_updated(self, ctx), EOutdated);
        let token_amount = balance::value(&token_balance);
        let withdraw_fee = ((((token_amount as u128)
            * (self.withdraw_fee_bpc as u128) + ((MAX_BPC - 1) as u128))
            / (MAX_BPC as u128)) as u64);
        let sui_amount = get_sui_amount(
            self,
            token_amount - withdraw_fee
        );

        let (sui_result, fresh_part) = withdraw_sui_internal(
            self,
            sui_system,
            sui_amount,
            ctx,
        );
        let result_total = balance::value(&sui_result);

        let (staked_result, staked_sui_withdrawn) = withdraw_fresh_stakes(
            self,
            sui_amount - result_total,
            ctx,
        );
        result_total = result_total + staked_sui_withdrawn;
        fresh_part = fresh_part + staked_sui_withdrawn;

        let token_result = balance::zero();

        let token_returned = 0;
        if (result_total < sui_amount) {
            // return non withdrawable part back as coins
            token_returned = get_token_amount(self, sui_amount - result_total);
            balance::join(
                &mut token_result,
                balance::split(&mut token_balance, token_returned)
            );
            token_amount = balance::value(&token_balance);
        };

        let token_fee = ((((get_token_amount(self, fresh_part) as u128)
            * (self.fresh_deposit_fee_bpc as u128)
            + ((MAX_BPC - 1) as u128))
                / (MAX_BPC as u128)) as u64);
        let fees_collected = math::min(withdraw_fee + token_fee, token_amount);
        let fee_balance = balance::split(
            &mut token_balance,
            fees_collected
        );
        balance::join(&mut self.fees, fee_balance);

        let token_burnt = balance::value(&token_balance);
        balance::decrease_supply(
            coin::supply_mut(&mut self.treasury),
            token_balance
        );
        
        self.current_sui_balance = self.current_sui_balance - result_total;

        event::emit(Withdrawn {
            stake_pool_id: object::id(self),
            token_burnt,
            sui_withdrawn: balance::value(&sui_result),
            staked_sui_withdrawn,
            token_returned,
            fees_collected,
            new_current_sui_balance: self.current_sui_balance,
            fresh_deposit_fee_bpc: self.fresh_deposit_fee_bpc,
            withdraw_fee_bpc: self.withdraw_fee_bpc,
            last_update_sui_balance: self.last_update_sui_balance,
            last_update_token_supply: self.last_update_token_supply
        });

        (sui_result, staked_result, token_result)
    }

    public entry fun withdraw<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        token: Coin<C>,
        ctx: &mut TxContext,
    ) {
        let (sui, staked, token) = withdraw_non_entry(
            self,
            sui_system,
            coin::into_balance(token),
            ctx
        );

        if (balance::value(&sui) > 0) {
            pay::keep(
                coin::from_balance(sui, ctx),
                ctx,
            );
        } else {
            balance::destroy_zero(sui);
        };
        let i = 0;
        let count = vector::length(&staked);
        let sender = tx_context::sender(ctx);
        while (i < count) {
            let stake = vector::pop_back(&mut staked);
            transfer::public_transfer(stake, sender);
            i = i + 1
        };
        vector::destroy_empty(staked);
        if (balance::value(&token) > 0) {
            pay::keep(
                coin::from_balance(token, ctx),
                ctx,
            )
        } else {
            balance::destroy_zero(token)
        }
    }

    public fun withdraw_sui_non_entry<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        token_balance: Balance<C>,
        ctx: &mut TxContext,
    ): Balance<SUI> {
        assert!(is_updated(self, ctx), EOutdated);
        let token_amount = balance::value(&token_balance);
        let withdraw_fee = ((((token_amount as u128)
            * (self.withdraw_fee_bpc as u128) + ((MAX_BPC - 1) as u128))
            / (MAX_BPC as u128)) as u64);
        let sui_amount = get_sui_amount(
            self,
            token_amount - withdraw_fee
        );

        let (sui_result, fresh_part) = withdraw_sui_internal(
            self,
            sui_system,
            sui_amount,
            ctx,
        );
        assert!(balance::value(&sui_result) >= sui_amount, ENotEnoughSuiToWithdraw);

        let token_fee = ((((get_token_amount(self, fresh_part) as u128)
            * (self.fresh_deposit_fee_bpc as u128)
            + ((MAX_BPC - 1) as u128))
                / (MAX_BPC as u128)) as u64);
        let fees_collected = math::min(withdraw_fee + token_fee, token_amount);
        let fee_balance = balance::split(
            &mut token_balance,
            fees_collected
        );
        balance::join(&mut self.fees, fee_balance);

        let token_burnt = balance::value(&token_balance);
        balance::decrease_supply(
            coin::supply_mut(&mut self.treasury),
            token_balance
        );
        
        self.current_sui_balance = self.current_sui_balance - sui_amount;

        event::emit(Withdrawn {
            stake_pool_id: object::id(self),
            token_burnt,
            sui_withdrawn: sui_amount,
            staked_sui_withdrawn: 0,
            token_returned: 0,
            fees_collected,
            new_current_sui_balance: self.current_sui_balance,
            fresh_deposit_fee_bpc: self.fresh_deposit_fee_bpc,
            withdraw_fee_bpc: self.withdraw_fee_bpc,
            last_update_sui_balance: self.last_update_sui_balance,
            last_update_token_supply: self.last_update_token_supply
        });

        sui_result
    }

    public entry fun withdraw_sui<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        token: Coin<C>,
        ctx: &mut TxContext,
    ) {
        let sui = withdraw_sui_non_entry(
            self,
            sui_system,
            coin::into_balance(token),
            ctx
        );

        pay::keep(
            coin::from_balance(sui, ctx),
            ctx,
        );
    }

    struct ReserveStaked has copy, drop {
        stake_pool_id: ID,
        validator_pool_id: ID,
        amount: u64,
    }

    fun stake_reserve_internal<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_address: address,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let stake_pool_id = object::id(self);
        let stake = sui_system::request_add_stake_non_entry(
            sui_system,
            coin::take(&mut self.reserve, amount, ctx),
            validator_address,
            ctx
        );
        let validator_pool_id = staking_pool::pool_id(&stake);
        let validator = stake_validator_entry(
            self,
            &stake
        );
        let (_, _) = validator_entry::add_stake(
            validator,
            sui_system,
            stake,
            ctx
        );
        event::emit(ReserveStaked {
            stake_pool_id,
            validator_pool_id,
            amount
        })
    }

    public entry fun forced_stake_reserve<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_address: address,
        amount: u64,
        cap: &ValidatorManagerCap<C>,
        ctx: &mut TxContext,
    ) {
        assert!(is_updated(self, ctx), EOutdated);
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );

        stake_reserve_internal(
            self,
            sui_system,
            validator_address,
            amount,
            ctx
        )
    }

    public entry fun stake_reserve<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        validator_address: address,
        ctx: &mut TxContext,
    ) {
        assert!(is_updated(self, ctx), EOutdated);
        assert!(
            is_staking_reserve_time(self, clock, ctx),
            ETooEarlyToStakeReserve
        );
        if (option::is_some(&self.staking_validator)) {
            assert!(
                *option::borrow(&self.staking_validator) == validator_address,
                EWrongValidatorAddress,
            );
        };
        let reserve_balance = balance::value(&self.reserve);
        stake_reserve_internal(
            self,
            sui_system,
            validator_address,
            reserve_balance,
            ctx
        )
    }

    public entry fun forced_unstake<C>(
        self: &mut StakePool<C>,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        amount: u64,
        cap: &ValidatorManagerCap<C>,
        ctx: &mut TxContext,
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        assert!(is_updated(self, ctx), EOutdated);
        let max_forced_unstake = (((self.current_sui_balance as u128) 
            * (self.max_forced_unstake_bpc as u128)
            / (MAX_BPC as u128)) as u64);
        assert!(
            self.current_forced_ustake + amount < max_forced_unstake,
            EForcedUstakeCapped
        );

        self.current_forced_ustake = self.current_forced_ustake + amount;

        let validator_index = validator_index(self, validator_pool_id);
        assert!(option::is_some(&validator_index), EValidatorDoesNotExist);
        let validator = vector::borrow_mut(
            &mut self.validators,
            option::destroy_some(validator_index)
        );
        let sui = validator_entry::withdraw(
            validator,
            sui_system,
            amount,
            ctx
        );
        balance::join(&mut self.reserve, sui);
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

    public fun is_staking_reserve_time<C>(
        self: &StakePool<C>,
        clock: &Clock,
        ctx: &TxContext
    ): bool {
        clock::timestamp_ms(clock) > tx_context::epoch_timestamp_ms(ctx)
            + self.keeping_reserve_ms
    }

    public fun staking_validator<C>(self: &StakePool<C>): Option<address> {
        self.staking_validator
    }

    struct StakingValidatorSet has copy, drop {
        stake_pool_id: ID,
        validator_address: Option<address>
    }

    public fun set_staking_validator<C>(
        self: &mut StakePool<C>,
        validator_address: Option<address>,
        cap: &ValidatorManagerCap<C>,
    ) {
        assert!(
            object::id(cap) == self.validator_manager_cap_id,
            EWrongValidatorManagerCap
        );
        let i = 0;
        if (option::is_some(&validator_address)) {
            let validator_address = *option::borrow(&validator_address);
            let count = vector::length(&self.validators);
            let found = false;
            while (i < count) {
                let validator = vector::borrow(&self.validators, i);
                if (validator_entry::validator_address(validator) == validator_address) {
                    found = true;
                    break
                };
                i = i + 1;
            };
            assert!(found, EWrongValidatorAddress);
        };
        self.staking_validator = validator_address;
        event::emit(StakingValidatorSet {
            stake_pool_id: object::id(self),
            validator_address,
        })
    }

    struct FeeWithdrawn has copy, drop {
        stake_pool_id: ID,
        amount: u64,
    }

    public fun withdraw_fees_non_entry<C>(
        self: &mut StakePool<C>,
        admin_cap: &AdminCap<C>,
    ): Balance<C> {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        event::emit(FeeWithdrawn {
            stake_pool_id: object::id(self),
            amount: balance::value(&self.fees)
        });
        balance::withdraw_all(&mut self.fees)
    }

    public entry fun withdraw_fees<C>(
        self: &mut StakePool<C>,
        admin_cap: &AdminCap<C>,
        ctx: &mut TxContext,
    ) {
        let result = withdraw_fees_non_entry(self, admin_cap);
        pay::keep(
            coin::from_balance(result, ctx),
            ctx
        )
    }

    public fun fresh_deposit_fee_bpc<C>(self: &StakePool<C>): u32 {
        self.fresh_deposit_fee_bpc
    }

    struct FreshDepositFeeBpcSet has copy, drop {
        stake_pool_id: ID,
        fresh_deposit_fee_bpc: u32,
    }

    public entry fun set_fresh_deposit_fee_bpc<C>(
        self: &mut StakePool<C>,
        fresh_deposit_fee_bpc: u32,
        admin_cap: &AdminCap<C>
    ) {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        self.fresh_deposit_fee_bpc = fresh_deposit_fee_bpc;
        event::emit(FreshDepositFeeBpcSet {
            stake_pool_id: object::id(self),
            fresh_deposit_fee_bpc,
        })
    }

    public fun withdraw_fee_bpc<C>(self: &StakePool<C>): u32 {
        self.withdraw_fee_bpc
    }

    struct WithdrawFeeBpcSet has copy, drop {
        stake_pool_id: ID,
        withdraw_fee_bpc: u32,
    }

    public entry fun set_withdraw_fee_bpc<C>(
        self: &mut StakePool<C>,
        withdraw_fee_bpc: u32,
        admin_cap: &AdminCap<C>
    ) {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        self.withdraw_fee_bpc = withdraw_fee_bpc;
        event::emit(WithdrawFeeBpcSet {
            stake_pool_id: object::id(self),
            withdraw_fee_bpc,
        })
    }

    public fun rewards_fee_bpc<C>(self: &StakePool<C>): u32 {
        self.rewards_fee_bpc
    }

    struct RewardsFeeBpcSet has copy, drop {
        stake_pool_id: ID,
        rewards_fee_bpc: u32,
    }

    public entry fun set_rewards_fee_bpc<C>(
        self: &mut StakePool<C>,
        rewards_fee_bpc: u32,
        admin_cap: &AdminCap<C>
    ) {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        self.rewards_fee_bpc = rewards_fee_bpc;
        event::emit(RewardsFeeBpcSet {
            stake_pool_id: object::id(self),
            rewards_fee_bpc,
        })
    }

    public fun keeping_reserve_ms<C>(self: &StakePool<C>): u64 {
        self.keeping_reserve_ms
    }

    struct KeepingReserveMsSet has copy, drop {
        stake_pool_id: ID,
        keeping_reserve_ms: u64,
    }

    public entry fun set_keeping_reserve_ms<C>(
        self: &mut StakePool<C>,
        keeping_reserve_ms: u64,
        admin_cap: &AdminCap<C>
    ) {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        self.keeping_reserve_ms = keeping_reserve_ms;
        event::emit(KeepingReserveMsSet {
            stake_pool_id: object::id(self),
            keeping_reserve_ms,
        })
    }

    public fun max_forced_unstake_bpc<C>(self: &StakePool<C>): u32 {
        self.max_forced_unstake_bpc
    }

    struct MaxForcedUnstakeBpcSet has copy, drop {
        stake_pool_id: ID,
        max_forced_unstake_bpc: u32,
    }

    public entry fun set_max_forced_unstake_bpc<C>(
        self: &mut StakePool<C>,
        max_forced_unstake_bpc: u32,
        admin_cap: &AdminCap<C>
    ) {
        assert!(object::id(admin_cap) == self.admin_cap_id, EWrongAdminCap);
        self.max_forced_unstake_bpc = max_forced_unstake_bpc;
        event::emit(MaxForcedUnstakeBpcSet {
            stake_pool_id: object::id(self),
            max_forced_unstake_bpc,
        })
    }
}