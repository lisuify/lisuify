module lisui_cetus_arbitrager::arbitrager {
    use cetus_clmm::pool::{Self, Pool};
    use cetus_clmm::config::GlobalConfig;
    use lisuify::stake_pool::{Self, StakePool};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::coin;
    use sui::pay;
    use sui::clock::{Self, Clock};
    use sui_system::sui_system::{Self, SuiSystemState};
    use std::vector;
    use sui::math;

    const MAX_BPC: u32 = 1000000;
    const PRICE_DENOMINATOR: u128 = 0x10000000000000000;
    const MIN_SQRT_PRICE: u128 = 4295048016;
    const MAX_SQRT_PRICE: u128 = 79226673515401279992447579055;

    const EWrongSwap: u64 = 1000;
    const EFailedToReachPrice: u64 = 1001;
    const EPrev: u64 = 1002;

    // swap liSUI -> SUI
    public fun supply_lisui_non_entry<C>(
        config: &GlobalConfig,
        swap_pool: &mut Pool<C, sui::sui::SUI>,
        stake_pool: &mut StakePool<C>,
        amount: u64,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext
    ): Balance<C> {
        let stake_pool_sui_balance = stake_pool::last_update_sui_balance(stake_pool);
        let stake_pool_token_supply = stake_pool::last_update_token_supply(stake_pool);
        let stake_pool_fresh_deposit_fee_bpc = stake_pool::fresh_deposit_fee_bpc(stake_pool);
        /*let lisui_price = (self.last_update_sui_balance as u256)
                * (PRICE_DENOMINATOR as u256)
                * (PRICE_DENOMINATOR as u256)
                * ((MAX_BPC - stake_pool_fresh_deposit_fee_bpc) as u256)
                / ((self.last_update_token_supply as u256) * (MAX_BPC au u256));
        // let lisui_sqrt_price = 
        */
        let (lisui_balance, sui_balance) = pool::balances(swap_pool);
        amount = balance::value(sui_balance);
        let swap_result = pool::calculate_swap_result(
            swap_pool,
            true,
            false,
            amount,
        );
        let steps = pool::calculate_swap_result_step_results(&swap_result);
        let i = 0;
        let count = vector::length(steps);
        let amount = 0;
        while (i < count) {
            let step = vector::borrow(steps, i);
            // let target_sqrt_price = pool::step_swap_result_target_sqrt_price(step);
            let current_sqrt_price = pool::step_swap_result_current_sqrt_price(step);
            if (current_sqrt_price < PRICE_DENOMINATOR) {
                break
            };
            amount = amount + pool::step_swap_result_amount_out(step);
            i = i + 1;
        };
        if (i > 0) {
            let step = vector::borrow(steps, i - 1);
            let current_sqrt_price = pool::step_swap_result_current_sqrt_price(step);
            let step_amount = pool::step_swap_result_amount_out(step);
            amount = amount - step_amount;
            let liquidity = pool::step_swap_result_current_liquidity(step);
            let part_amount = (((liquidity as u256) 
                * ((current_sqrt_price - PRICE_DENOMINATOR) as u256)
                / (PRICE_DENOMINATOR as u256)) as u64);
            assert!(part_amount <= step_amount, 1003);
            amount = amount + part_amount
        };

        swap_result = pool::calculate_swap_result(
            swap_pool,
            true,
            false,
            amount,
        );
        let v = pool::calculated_swap_result_after_sqrt_price(&swap_result);
        if (v > PRICE_DENOMINATOR) {
            assert!(v - PRICE_DENOMINATOR < PRICE_DENOMINATOR / 10000, EFailedToReachPrice);
        } else {
            assert!(PRICE_DENOMINATOR - v < PRICE_DENOMINATOR / 10000, EFailedToReachPrice);
        };

        let (receive_lisui, receive_sui, flash_receipt) = pool::flash_swap(
            config,
            swap_pool,
            true,
            false,
            amount,
            MIN_SQRT_PRICE,
            clock
        );
        let pay_amount = pool::swap_pay_amount(&flash_receipt);
        let lisui = stake_pool::deposit_sui_non_entry(
            stake_pool,
            sui_system,
            clock,
            coin::from_balance(receive_sui, ctx),
            ctx,
        );
        balance::join(&mut lisui, receive_lisui);
        assert!(balance::value(&lisui) > pay_amount, EWrongSwap);
        let payment = balance::split(&mut lisui, pay_amount);
        pool::repay_flash_swap(
            config,
            swap_pool,
            payment,
            balance::zero(),
            flash_receipt
        );
        lisui
    }

    public entry fun supply_lisui<C>(
        config: &GlobalConfig,
        swap_pool: &mut Pool<C, sui::sui::SUI>,
        stake_pool: &mut StakePool<C>,
        amount: u64,
        sui_system: &mut SuiSystemState,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let lisui = supply_lisui_non_entry<C>(
            config,
            swap_pool,
            stake_pool,
            amount,
            sui_system,
            clock,
            ctx
        );
        pay::keep(
            coin::from_balance(lisui, ctx),
            ctx
        );
    }
}