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

    friend lisuify::stake_pool;

    const EWrongValidatorPool: u64 = 10;
    const EDestroyingWithStakes: u64 = 12;
    const EOutdated: u64 = 13;
    const EDeactivated: u64 = 14;
    const ENotEnoughRewards: u64 = 15; // TODO: just not unstake in this case

    struct ValidatorEntry<phantom C> has key, store {
        id: UID,
        stake_pool_id: ID,
        validator_pool_id: ID,
        is_active: bool,
        last_update_epoch: u64,
        last_update_sui_balance: u64,
        stakes: ObjectTable<u64, StakedSui>, // activation_epoch -> StakedSui
        stake_activation_epochs: vector<u64>,
    }

    public(friend) fun new<C>(
        stake_pool_id: ID,
        validator_pool_id: ID,
        ctx: &mut TxContext)
    : ValidatorEntry<C>
    {
        let epoch = tx_context::epoch(ctx);

        ValidatorEntry {
            id: object::new(ctx),
            stake_pool_id,
            validator_pool_id,
            is_active: true,
            last_update_epoch: epoch,
            last_update_sui_balance: 0,
            stakes: object_table::new(ctx),
            stake_activation_epochs: vector::empty()
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

    fun get_token_amount(exchange_rate: &PoolTokenExchangeRate, sui_amount: u64): u64 {
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
    ): Option<PoolTokenExchangeRate> {
        let exchange_rates = sui_system::pool_exchange_rates(
            sui_system,
            &validator_pool_id
        );
        if (table::is_empty(exchange_rates)) {
            return option::none()
        };
        // Find the latest epoch that's earlier than the given epoch with an entry in the table
        while (true) {
            if (table::contains(exchange_rates, epoch)) {
                return option::some(*table::borrow(exchange_rates, epoch))
            };
            epoch = epoch - 1;
        };
        option::none()
    }

    public(friend) fun update<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        ctx: &TxContext,
    ): u64 {
        assert!(validator_pool_id == self.validator_pool_id, EWrongValidatorPool);
        let epoch = tx_context::epoch(ctx);
        if (epoch == self.last_update_epoch) {
            return self.last_update_sui_balance
        };

        
        let exchange_rate = pool_exchange_rate_at_epoch(
            sui_system,
            validator_pool_id,
            epoch
        );

        if (option::is_none(&exchange_rate)) {
            return self.last_update_sui_balance
        };

        let exchange_rate = option::destroy_some(exchange_rate);

        let total = 0;

        let i = 0;
        let stake_count = vector::length(&self.stake_activation_epochs);
        while (i < stake_count) {
            let stake_activation_epoch = *vector::borrow(&self.stake_activation_epochs, i);
            let stake = object_table::borrow(&self.stakes, stake_activation_epoch);
            total = total + stake_balance_internal(
                stake,
                sui_system,
                validator_pool_id,
                &exchange_rate
            );
            i = i + 1;
        };

        self.last_update_epoch = epoch;
        self.last_update_sui_balance = total;

        total
    }

    public fun validator_pool_id<C>(self: &ValidatorEntry<C>): ID {
        self.validator_pool_id
    }

    public(friend) fun destroy_empty<C>(self: ValidatorEntry<C>) {
        let ValidatorEntry {
            id,
            stake_pool_id: _,
            validator_pool_id: _,
            is_active: _,
            last_update_epoch: _,
            last_update_sui_balance: _,
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

    /*
    fun is_updated<C>(
        self: &mut ValidatorEntry<C>,
        ctx: &TxContext,
    ): bool {
        let epoch = tx_context::epoch(ctx);
        epoch == self.last_update_epoch
    }
    */

    public(friend) fun add_stake<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        stake: StakedSui,
        ctx: &TxContext,
    ): u64 {
        assert!(self.is_active, EDeactivated);
        assert!(staking_pool::pool_id(&stake) == self.validator_pool_id, EWrongValidatorPool);

        let epoch = tx_context::epoch(ctx);
        let exchange_rate = option::destroy_some(
            pool_exchange_rate_at_epoch(
                sui_system,
                self.validator_pool_id,
                epoch
            )
        );

        let stake_activation_epoch = staking_pool::stake_activation_epoch(&stake);
        if (object_table::contains(&self.stakes, stake_activation_epoch)) {
            let target_stake = object_table::borrow_mut(
                &mut self.stakes,
                stake_activation_epoch
            );
            let target_balance = stake_balance_internal(
                target_stake,
                sui_system,
                self.validator_pool_id,
                &exchange_rate
            );
            staking_pool::join_staked_sui(target_stake, stake);
            let joined_balance = stake_balance_internal(
                target_stake,
                sui_system,
                self.validator_pool_id,
                &exchange_rate
            );
            joined_balance - target_balance
        } else {
            let stake_balance = stake_balance_internal(
                &stake,
                sui_system,
                self.validator_pool_id,
                &exchange_rate
            );
            object_table::add(&mut self.stakes, stake_activation_epoch, stake);
            vector::push_back(
                &mut self.stake_activation_epochs,
                stake_activation_epoch
            );
            stake_balance
        }
    }

    fun stake_balance_internal(
        stake: &StakedSui,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        exchange_rate: &PoolTokenExchangeRate
    ): u64 {
        let staked_amount = staking_pool::staked_sui_amount(stake);
        let pool_token_withdraw_amount = {
            let exchange_rate_at_staking_epoch = option::destroy_some(
                pool_exchange_rate_at_epoch(
                    sui_system,
                    validator_pool_id,
                    staking_pool::stake_activation_epoch(stake)
                )
            );
            get_token_amount(&exchange_rate_at_staking_epoch, staked_amount)
        };
        get_sui_amount(exchange_rate, pool_token_withdraw_amount)
    }

    public(friend) fun stake_balance(
        stake: &StakedSui,
        sui_system: &mut SuiSystemState,
        validator_pool_id: ID,
        ctx: &TxContext,
    ): u64 {
        let epoch = tx_context::epoch(ctx);
        let exchange_rate = option::destroy_some(
            pool_exchange_rate_at_epoch(
                sui_system,
                validator_pool_id,
                epoch
            )
        );
        
        stake_balance_internal(
            stake,
            sui_system,
            validator_pool_id,
            &exchange_rate
        )
    }

    public(friend) fun withdraw_fresh<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        max_amount: u64,
        ctx: &mut TxContext,
    ): Balance<SUI> {
        if (max_amount == 0) {
            return balance::zero()
        };
        let epoch = tx_context::epoch(ctx);
        if (object_table::contains(&self.stakes, epoch + 1)) {
            let stake = object_table::borrow_mut(
                &mut self.stakes,
                epoch + 1
            );
            let stake_balance = stake_balance(
                stake,
                sui_system,
                self.validator_pool_id,
                ctx,
            );
            let source_stake = if (stake_balance > max_amount) {
                staking_pool::split(
                    stake,
                    max_amount,
                    ctx
                )
            } else {
                let (_, i) = vector::index_of(
                    &self.stake_activation_epochs,
                    &(epoch + 1)
                );
                vector::swap_remove(
                    &mut self.stake_activation_epochs,
                    i
                );
                object_table::remove(
                    &mut self.stakes,
                    epoch + 1
                )
            };
            stake_balance = stake_balance(
                &source_stake,
                sui_system,
                self.validator_pool_id,
                ctx,
            );
            let sui = sui_system::request_withdraw_stake_non_entry(
                sui_system,
                source_stake,
                ctx
            );
            assert!(
                balance::value(&sui) == stake_balance,
                ENotEnoughRewards
            );
            sui
        } else {
            balance::zero()
        }
    }

    public(friend) fun withdraw<C>(
        self: &mut ValidatorEntry<C>,
        sui_system: &mut SuiSystemState,
        max_amount: u64,
        ctx: &mut TxContext,
    ): Balance<SUI> {
        let result = balance::zero();
        let i = 0;
        let count = vector::length(&self.stake_activation_epochs);
        while (i < count && max_amount > 0) {
            let epoch = *vector::borrow(&self.stake_activation_epochs, i);
            let stake = object_table::borrow_mut(
                &mut self.stakes,
                epoch
            );
            let stake_balance = stake_balance(
                stake,
                sui_system,
                self.validator_pool_id,
                ctx,
            );
            let source_stake = if (stake_balance > max_amount) {
                staking_pool::split(
                    stake,
                    max_amount,
                    ctx
                )
            } else {
                vector::swap_remove(
                    &mut self.stake_activation_epochs,
                    i
                );
                object_table::remove(
                    &mut self.stakes,
                    epoch
                )
            };
            stake_balance = stake_balance(
                &source_stake,
                sui_system,
                self.validator_pool_id,
                ctx,
            );
            let sui = sui_system::request_withdraw_stake_non_entry(
                sui_system,
                source_stake,
                ctx
            );
            assert!(
                balance::value(&sui) == stake_balance,
                ENotEnoughRewards
            );
            max_amount = max_amount - stake_balance;
            balance::join(&mut result, sui);
            i = i + 1;
        };
        result
    }

    public fun last_update_sui_balance<C>(self: &ValidatorEntry<C>): u64 {
        self.last_update_sui_balance
    }
}