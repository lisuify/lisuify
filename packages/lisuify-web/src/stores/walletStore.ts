import {
  createWalletKitCore,
  type WalletKitCore,
} from "@mysten/wallet-kit-core";
import { atom } from "nanostores";
import type { StakedSuiObjectData, WalletData, WalletState } from "../types";
import {
  getLiSuiCoins,
  getStakedSUIObjects,
  getSuiBalance,
} from "../client/rpc";
import type { SuiObjectData, SuiValidatorSummary } from "@mysten/sui.js/client";
import { log } from "../utils";
import { suiSystemStateAtom } from "./suiSystemStateStore";

const suiSystemState = suiSystemStateAtom.get();
const validatorsMap: { [name: string]: SuiValidatorSummary } = {}; // map pool id to validator summary
suiSystemState?.activeValidators.forEach((validator) => {
  validatorsMap[validator.stakingPoolId] = validator;
});
log("validatorsMap", validatorsMap);

const SUI_WALLET_NAME = "Sui Wallet";
const defaultWallet = {
  wallets: [],
  walletIdx: 0,
};

export const walletKit: WalletKitCore = createWalletKitCore({
  preferredWallets: [SUI_WALLET_NAME],
});
export const walletStateAtom = atom<WalletState>(defaultWallet);

export const getWalletAddresses = async () => {
  let wallets: WalletData[] = [];
  walletKit.getState().accounts.forEach((ac) => {
    wallets.push({
      walletAccount: ac,
      suiBalance: BigInt(0),
      liSuiCoins: [],
      liSuiBalance: BigInt(0),
      stakedSuiObjects: [],
    });
  });

  walletStateAtom.set({
    wallets,
    walletIdx: 0,
  });
};

export const getWalletBalances = async () => {
  const newWallets = walletStateAtom.get().wallets.map(async (wallet) => {
    // get sui balance
    const suiCoinBalance = await getSuiBalance(wallet.walletAccount.address);
    wallet.suiBalance = BigInt(suiCoinBalance.totalBalance);

    // get lisui balance
    const liSuiCoins = await getLiSuiCoins(wallet.walletAccount.address);
    wallet.liSuiCoins = liSuiCoins;
    let liSuiBalance = BigInt(0);
    liSuiCoins.forEach((coin) => {
      liSuiBalance += BigInt(coin.balance);
    });
    wallet.liSuiBalance = liSuiBalance;

    // get staked sui objects
    const getStakedSUIObjectsResp = await getStakedSUIObjects(
      wallet.walletAccount.address
    );
    let stakedSuiObjects: SuiObjectData[] = [];
    getStakedSUIObjectsResp.data.forEach((obj) => {
      if (obj.data) {
        stakedSuiObjects.push(obj.data);
      }
    });
    wallet.stakedSuiObjects = stakedSuiObjects as StakedSuiObjectData[];
    wallet.stakedSuiObjects = wallet.stakedSuiObjects.map((stakedSui) => {
      stakedSui.validator = validatorsMap[stakedSui.content.fields.pool_id];
      return stakedSui;
    });

    log("wallet", wallet);

    return wallet;
  });

  Promise.all(newWallets).then((wallets) => {
    walletStateAtom.set({
      wallets: wallets,
      walletIdx: 0,
    });
  });
};

export const connectWallet = async () => {
  await walletKit.connect(SUI_WALLET_NAME);
  await getWalletAddresses();
  await getWalletBalances();
};

export const disconnectWallet = async () => {
  await walletKit.disconnect();
  walletStateAtom.set(defaultWallet);
};

export const changeWallet = async (newIdx: number) => {
  const newWalletState = walletStateAtom.get();

  walletKit.selectAccount(newWalletState.wallets[newIdx].walletAccount);
  newWalletState.walletIdx = newIdx;

  walletStateAtom.set({ ...newWalletState });
};
