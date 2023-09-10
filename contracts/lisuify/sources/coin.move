module lisuify::coin {
    use std::option;
    use sui::coin::{Self};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use lisuify::stake_pool;

    struct COIN has drop {}
    
    fun init(witness: COIN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"liSUI",
            b"Liquid staked SUI",
            b"Coin representation of the staked SUI",
            option::none(),
            ctx);
        transfer::public_freeze_object(metadata);
        let (admin_cap, validator_manager_cap) = stake_pool::new<COIN>(treasury, ctx);
        transfer::public_transfer(admin_cap, tx_context::sender(ctx));
        transfer::public_transfer(validator_manager_cap, tx_context::sender(ctx))
    }
}