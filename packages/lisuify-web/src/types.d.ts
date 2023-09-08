import type {
  SuiObjectData,
  SuiSystemStateSummary,
} from "@mysten/sui.js/client";
import type { WalletAccount } from "@mysten/wallet-standard";

export interface StakedSuiObjectData extends SuiObjectData {
  content: {
    dataType: "moveObject";
    fields: {
      id: {
        id: string;
      };
      pool_id: string;
      principal: string;
      stake_activation_epoch: string;
      validatorName?: string; // custom type
    };
    hasPublicTransfer: boolean;
    type: string;
  };
}

export interface WalletData {
  walletAccount: WalletAccount;
  suiBalance: bigint;
  stakedSuiObjects: StakedSuiObjectData[];
}

export interface WalletState {
  wallets: WalletData[];
  walletIdx: number;
}

export interface SuiSystemStateSummaryData extends SuiSystemStateSummary {}
