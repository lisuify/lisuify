# LiSuify

[LiSuify](https://lisuify.com/) is a liquid staking platform for the SUI protocol, enabling users to stake their SUI or [StakedSui object](https://lisuify.com/docs/getting-started/what-is-lisuify/#what-is-stakedsui) to wrap with a liquid token name [liSUI](https://lisuify.com/docs/getting-started/what-is-lisuify/#what-is-lisui) return to user. The staked SUI tokens are delegated across multiple validators to earning staking rewards.

## Project Structure

```tree
.
├── contracts
│   └── lisuify             - LiSuify smart contracts
└── packages
    ├── lisuify-cli         - LiSuify command line interface
    ├── lisuify-sdk         - LiSuify SDK
    └── lisuify-web         - LiSuify Web
```

## Development

developer need to install [pnpm](https://pnpm.io/) to use [pnpm workspace](https://pnpm.io/workspaces)

### Install pnpm

`npm install -g pnpm`

### Install packages

`pnpm install`

### LiSuify packages

[lisuify-web](/packages/lisuify-web) - LiSuify Web

[lisuify-sdk](/packages/lisuify-sdk) - LiSuify SDK

[lisuify-cli](/packages/lisuify-cli) - LiSuify command line interface
