import type {
  CoinStruct,
  SuiObjectData,
  SuiSystemStateSummary,
  SuiValidatorSummary,
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
    }; // custom fields for staked sui object
    hasPublicTransfer: boolean;
    type: string;
  };
  validator?: SuiValidatorSummary; // custom type
}

export interface WalletData {
  walletAccount: WalletAccount;
  suiBalance: bigint;
  liSuiBalance: bigint;
  stakedSuiObjects: StakedSuiObjectData[];
  liSuiCoins: CoinStruct[];
}

export interface WalletState {
  wallets: WalletData[];
  walletIdx: number;
}

export interface Stats {
	loading: boolean;
  totalSuiStaking: bigint;
  liSuiRatio: number;
  validatorApy: number;
}

export interface SuiSystemStateSummaryData extends SuiSystemStateSummary {}
