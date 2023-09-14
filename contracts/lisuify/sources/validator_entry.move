module lisuify::validator_entry {
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};
    use sui_system::staking_pool::{Self, StakedSui, PoolTokenExchangeRate};
    use std::vector;
    use sui_system::sui_system::{Self, SuiSystemState};
    use sui::table;
    use sui::object_table::{Self, ObjectTable};
    use sui::math;

    friend lisuify::stake_pool;

    const EWrongValidatorPool: u64 = 1000;
    const EDestroyingWithStakes: u64 = 1001;
    const EValidatorOutdated: u64 = 1002;
    const EDeactivated: u64 = 1003;
    const ESlashed: u64 = 1004;
    const EUknownPoolExchangeRate: u64 = 1005;

    /// StakedSui objects cannot be split to below this amount.
    const MIN_STAKING_THRESHOLD: u64 = 1_000_000_000; // 1 SUI

    struct ValidatorEntry<phantom C> has key, store {
        id: UID,
        stake_pool_id: ID,
        validator_pool_id: ID,
        validator_address: address,
        is_active: bool,
        current_pool_tokens: u64,
        current_fresh_sui_balance: u64,
        last_update_epoch: u64,
        last_update_sui_balance: u64,
        last_update_pool_exchange_rate: PoolTokenExchangeRate,
        stakes: ObjectTable<u64, StakedSui>, // activation_epoch -> StakedSui
        stake_activation_epochs: vector<u64>,
    }

    public(friend) fun new<C>(
        sui_system: &mut SuiSystemState,
        stake_pool_id: ID,
        validator_pool_id: ID,
        validator_address: address,
        ctx: &mut TxContext)
    : ValidatorEntry<C>
    {
        let epoch = tx_context::epoch(ctx);
        // check the validator pool
        let last_update_pool_exchange_rate = pool_exchange_rate_at_epoch(
            sui_system,
            validator_pool_id,
            epoch
        );

        ValidatorEntry {
            id: object::new(ctx),
            stake_pool_id,
            validator_pool_id,
            validator_address,
            is_active: true,
            current_pool_tokens: 0,
            current_fresh_sui_balance: 0,
            last_update_epoch: epoch,
            last_update_sui_balance: 0,
            last_update_pool_exchange_rate,
            stakes: object_table::new(ctx),
            stake_activation_epochs: vector::empty()
        }
    }

    public fun current_pool_exchange_rate<C>(
        self: &ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        ctx: &TxContext
    ): PoolTokenExchangeRate {
        let epoch = tx_context::epoch(ctx);
        if (self.last_update_epoch == epoch) {
            self.last_update_pool_exchange_rate
        } else {
            pool_exchange_rate_at_epoch(
                sui_system,
                self.validator_pool_id,
                epoch
            )
        }
    }

    fun get_sui_amount(exchange_rate: &PoolTokenExchangeRate, token_amount: u64): u64 {
        let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);

        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
            return token_amount
        };
        let res = (exchange_rate_sui_amount as u128)
                * (token_amount as u128)
                / (exchange_rate_pool_token_amount as u128);
        (res as u64)
    }

    fun get_pool_token_amount(exchange_rate: &PoolTokenExchangeRate, sui_amount: u64): u64 {
        let exchange_rate_sui_amount = staking_pool::sui_amount(exchange_rate);
        let exchange_rate_pool_token_amount = staking_pool::pool_token_amount(exchange_rate);
        
        // When either amount is 0, that means we have no stakes with this pool.
        // The other amount might be non-zero when there's dust left in the pool.
        if (exchange_rate_sui_amount == 0 || exchange_rate_pool_token_amount == 0) {
            return sui_amount
        };
        let res = (exchange_rate_pool_token_amount as u128)
                * (sui_amount as u128)
                / (exchange_rate_sui_amount as u128);
        (res as u64)
    }

    fun pool_exchange_rate_at_epoch(
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        epoch: u64,
    ): PoolTokenExchangeRate {
        let exchange_rates = sui_system::pool_exchange_rates(
            sui_system,
            &validator_pool_id
        );
        assert!(!table::is_empty(exchange_rates), EUknownPoolExchangeRate);
        // Find the latest epoch that's earlier than the given epoch with an entry in the table
        while (true) {
            if (table::contains(exchange_rates, epoch)) {
                return *table::borrow(exchange_rates, epoch)
            };
            assert!(epoch > 0, EUknownPoolExchangeRate);
            epoch = epoch - 1;
        };
        abort EUknownPoolExchangeRate
    }

    public(friend) fun update<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        ctx: &TxContext,
    ): u64 {
        let epoch = tx_context::epoch(ctx);
        if (epoch == self.last_update_epoch) {
            return self.last_update_sui_balance
        };
        
        self.last_update_pool_exchange_rate = pool_exchange_rate_at_epoch(
            sui_system,
            self.validator_pool_id,
            epoch
        );

        // register previously fresh stakes
        let e = self.last_update_epoch + 1;
        // must have one stake maximum on e = self.last_update_epoch + 1
        while (e <= epoch) {
            if (object_table::contains(&self.stakes, e)) {
                let stake = object_table::borrow(&self.stakes, e);
                let pool_token_amount = stake_pool_token_amount(
                    sui_system,
                    stake
                );
                self.current_pool_tokens = self.current_pool_tokens + pool_token_amount;
            };
            e = e + 1;
        };
        self.current_fresh_sui_balance = 0;
        if (object_table::contains(&self.stakes, epoch + 1)) {
            let stake = object_table::borrow(&self.stakes, epoch + 1);
            self.current_fresh_sui_balance = staking_pool::staked_sui_amount(stake);
        };

        let current_active_sui_balance = get_sui_amount(
            &self.last_update_pool_exchange_rate,
            self.current_pool_tokens
        );

        self.last_update_epoch = epoch;
        self.last_update_sui_balance = 
            current_active_sui_balance
                + self.current_fresh_sui_balance;

        self.last_update_sui_balance
    }

    public(friend) fun validator_pool_id<C>(self: &ValidatorEntry<C>): ID {
        self.validator_pool_id
    }

    public(friend) fun validator_address<C>(self: &ValidatorEntry<C>): address {
        self.validator_address
    }

    public(friend) fun destroy_empty<C>(self: ValidatorEntry<C>) {
        let ValidatorEntry {
            id,
            stake_pool_id: _,
            validator_pool_id: _,
            validator_address: _,
            is_active: _,
            current_pool_tokens: _,
            current_fresh_sui_balance: _,
            last_update_epoch: _,
            last_update_sui_balance: _,
            last_update_pool_exchange_rate: _,
            stakes,
            stake_activation_epochs,
        } = self;
        assert!(
            vector::length(&stake_activation_epochs) == 0,
            EDestroyingWithStakes
        );
        object::delete(id);
        vector::destroy_empty(stake_activation_epochs);
        object_table::destroy_empty(stakes)
    }

    fun stake_pool_token_amount(
        sui_system: &mut SuiSystemState,
        stake: &StakedSui,
    ): u64 {
        let validator_pool_id = staking_pool::pool_id(stake);
        let stake_activation_epoch = staking_pool::stake_activation_epoch(stake);
        let exchange_rate_at_staking_epoch = pool_exchange_rate_at_epoch(
            sui_system,
            validator_pool_id,
            stake_activation_epoch
        );
        let staked_amount = staking_pool::staked_sui_amount(stake);
        get_pool_token_amount(&exchange_rate_at_staking_epoch, staked_amount)
    }

    public(friend) fun add_stake<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &mut TxContext,
    ): (u64, bool) { // balance, is_fresh
        assert!(self.is_active, EDeactivated);
        let validator_pool_id = staking_pool::pool_id(&stake);
        assert!(self.validator_pool_id == validator_pool_id, EWrongValidatorPool);
        let epoch = tx_context::epoch(ctx);
        assert!(epoch == self.last_update_epoch, EValidatorOutdated); // ruining invariants otherwise
        
        let stake_activation_epoch = staking_pool::stake_activation_epoch(&stake);
        let staked_amount = staking_pool::staked_sui_amount(&stake);
        let pool_token_amount = stake_pool_token_amount(
            sui_system,
            &stake
        );

        if (object_table::contains(&self.stakes, stake_activation_epoch)) {
            let target_stake = object_table::borrow_mut(
                &mut self.stakes,
                stake_activation_epoch
            );
            staking_pool::join_staked_sui(target_stake, stake);
        } else {
            object_table::add(&mut self.stakes, stake_activation_epoch, stake);
            vector::push_back(
                &mut self.stake_activation_epochs,
                stake_activation_epoch
            );
        };

        let is_fresh = stake_activation_epoch > epoch;
        let amount = if (is_fresh) {
            self.current_fresh_sui_balance = self.current_fresh_sui_balance + staked_amount;
            staked_amount
        } else {
            let old_active_sui_balance = get_sui_amount(
                &self.last_update_pool_exchange_rate,
                self.current_pool_tokens
            );
            self.current_pool_tokens = self.current_pool_tokens + pool_token_amount;
            let current_active_sui_balance = get_sui_amount(
                &self.last_update_pool_exchange_rate,
                self.current_pool_tokens
            );
            current_active_sui_balance - old_active_sui_balance
        };
        (amount, is_fresh)
    }

    fun stake_balance_internal(
        sui_system: &mut SuiSystemState,
        stake: &StakedSui,
        exchange_rate: &PoolTokenExchangeRate
    ): u64 {
        let staked_amount = staking_pool::staked_sui_amount(stake);
        let pool_token_amount = stake_pool_token_amount(sui_system, stake);
        let result = get_sui_amount(exchange_rate, pool_token_amount);
        assert!(result >= staked_amount, ESlashed);
        result
    }

    public(friend) fun stake_balance<C>(
        self: &ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        stake: &StakedSui,
        ctx: &TxContext,
    ): u64 {
        assert!(
            staking_pool::pool_id(stake) == self.validator_pool_id,
            EWrongValidatorPool
        );
        let exchange_rate = current_pool_exchange_rate(
            self,
            sui_system,
            ctx,
        );
        stake_balance_internal(
            sui_system,
            stake,
            &exchange_rate
        )
    }

    public(friend) fun withdraw_fresh<C>(
        self: &mut ValidatorEntry<C>,
        max_amount: u64,
        ctx: &mut TxContext,
    ): Option<StakedSui> {
        if (max_amount < MIN_STAKING_THRESHOLD) {
            return option::none()
        };
        let epoch = tx_context::epoch(ctx);
        if (object_table::contains(&self.stakes, epoch + 1)) {
            let stake = object_table::borrow_mut(
                &mut self.stakes,
                epoch + 1
            );
            let stake_balance = staking_pool::staked_sui_amount(stake);
            if (stake_balance >= max_amount + MIN_STAKING_THRESHOLD) {
                self.current_fresh_sui_balance = self.current_fresh_sui_balance - max_amount;
                option::some(
                    staking_pool::split(
                        stake,
                        max_amount,
                        ctx
                    )
                )
            } else if (stake_balance <= max_amount) {
                self.current_fresh_sui_balance = self.current_fresh_sui_balance - stake_balance;
                let (_, i) = vector::index_of(
                    &self.stake_activation_epochs,
                    &(epoch + 1)
                );
                vector::swap_remove(
                    &mut self.stake_activation_epochs,
                    i
                );
                option::some(object_table::remove(
                    &mut self.stakes,
                    epoch + 1
                ))
            } else {
                option::none()
            }
        } else {
            option::none()
        }
    }

    public(friend) fun withdraw<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        max_amount: u64,
        ctx: &mut TxContext,
    ): Balance<SUI> {
        let epoch = tx_context::epoch(ctx);
        assert!(epoch == self.last_update_epoch, EValidatorOutdated); // ruining invariants otherwise
        let result = balance::zero();
        let i = 0;
        let count = vector::length(&self.stake_activation_epochs);
        let exchange_rate = current_pool_exchange_rate(
            self,
            sui_system,
            ctx
        );
        while (i < count && max_amount > 0) {
            if (max_amount < MIN_STAKING_THRESHOLD) {
                max_amount = MIN_STAKING_THRESHOLD;
            };
            let stake_activation_epoch = *vector::borrow(&self.stake_activation_epochs, i);
            if (stake_activation_epoch == epoch + 1) {
                // skip fresh stake
                i = i + 1;
                continue
            };
            let stake = object_table::borrow_mut(
                &mut self.stakes,
                stake_activation_epoch
            );
            let principal = staking_pool::staked_sui_amount(stake);
            let stake_activation_epoch = staking_pool::stake_activation_epoch(stake);

            let exchange_rate_at_staking_epoch = pool_exchange_rate_at_epoch(
                sui_system,
                self.validator_pool_id,
                stake_activation_epoch,
            );
            let split_request_pool_tokens = get_pool_token_amount(
                &exchange_rate,
                max_amount,
            );
            while (get_sui_amount(&exchange_rate, split_request_pool_tokens) < max_amount) {
                split_request_pool_tokens = split_request_pool_tokens + 1;
            };
            let split_request = get_sui_amount(
                &exchange_rate_at_staking_epoch,
                split_request_pool_tokens
            );
            while (get_pool_token_amount(&exchange_rate_at_staking_epoch, split_request) < split_request_pool_tokens) {
                split_request = split_request + 1;
            };
            let source_stake = if (principal >= split_request + MIN_STAKING_THRESHOLD) {
                self.current_pool_tokens = self.current_pool_tokens -  split_request_pool_tokens;
                staking_pool::split(
                    stake,
                    split_request,
                    ctx
                )
            } else {
                self.current_pool_tokens = 
                    self.current_pool_tokens
                        - get_pool_token_amount(&exchange_rate_at_staking_epoch, principal);  
                vector::swap_remove(
                    &mut self.stake_activation_epochs,
                    i
                );
                object_table::remove(
                    &mut self.stakes,
                    stake_activation_epoch
                )
            };
            let sui = sui_system::request_withdraw_stake_non_entry(
                sui_system,
                source_stake,
                ctx
            );
            max_amount = max_amount - math::min(balance::value(&sui), max_amount);
            balance::join(&mut result, sui);
            i = i + 1;
        };
        result
    }

    public(friend) fun last_update_sui_balance<C>(self: &ValidatorEntry<C>): u64 {
        self.last_update_sui_balance
    }

    public(friend) fun is_active<C>(self: &ValidatorEntry<C>): bool {
        self.is_active
    }

    public(friend) fun set_is_active<C>(
        self: &mut ValidatorEntry<C>,
        is_active: bool
    ) {
        self.is_active = is_active
    }
}