# LiSuify

[LiSuify](https://lisuify.com/) is a liquid staking platform for the SUI protocol, enabling users to stake their SUI or [StakedSui object](https://lisuify.com/docs/getting-started/what-is-lisuify/#what-is-stakedsui) to wrap with a liquid token name [liSUI](https://lisuify.com/docs/getting-started/what-is-lisuify/#what-is-lisui) return to the user. The staked SUI tokens are delegated across multiple validators to contributing to the SUI protocol's Proof-of-Stake (PoS) consensus mechanism and earning staking rewards.

## LiSuify packages

[LiSuify Smart Contract](/contracts/lisuify) - LiSuify smart contracts

[lisuify-web](/packages/lisuify-web) - LiSuify Web

[lisuify-sdk](/packages/lisuify-sdk) - LiSuify SDK

[lisuify-cli](/packages/lisuify-cli) - LiSuify command line interface

### Project Structure

```tree
.
├── contracts
│   ├── lisuify              - LiSuify smart contract
│   └── LisuiCetusArbitrager - Cetus integration contract
└── packages
    ├── lisuify-cli          - LiSuify command line interface
    ├── lisuify-sdk          - LiSuify SDK
    └── lisuify-web          - LiSuify Web
```

## Documents

[What is LiSuify?](https://lisuify.com/docs/getting-started/what-is-lisuify/)

[Staking Pool Whitepaper](https://lisuify.com/docs/lisuify/whitepaper/)

[Tokenomics](https://lisuify.com/docs/lisuify/tokenomics/)

[Liquid Staking Contract API Reference](https://lisuify.com/docs/lisuify/api-reference/)
[Cetus Integartion Plans](https://lisuify.com/docs/lisuify/cetus-integration/)

## Development

developer need to install [pnpm](https://pnpm.io/) to use [pnpm workspace](https://pnpm.io/workspaces)

### Install pnpm

`npm install -g pnpm`

### Install packages

`pnpm install`
