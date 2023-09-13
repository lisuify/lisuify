import type { CoinStruct } from "@mysten/sui.js/client";
import { originalLisuifyId } from "../consts";
import { client } from "./client";

export const getSuiBalance = (address: string) => {
  return client.getBalance({
    owner: address,
  });
};

export const getLiSuiBalance = async (address: string) => {
  return client.getBalance({
    owner: address,
    coinType: `${originalLisuifyId}::coin::COIN`,
  });
};

export const getLiSuiCoins = async (address: string) => {
  const result: CoinStruct[] = [];
  let cursor: string | null | undefined;
  for (;;) {
    const r = await client.getCoins({
      owner: address,
      coinType: `${originalLisuifyId}::coin::COIN`,
    });
    result.push(...r.data);
    if (!r.hasNextPage) {
      return result;
    }
    cursor = r.nextCursor;
  }
};

export const getStakedSUIObjects = (address: string) => {
  return client.getOwnedObjects({
    owner: address,
    filter: {
      StructType: "0x3::staking_pool::StakedSui",
    },
    options: {
      showContent: true,
    },
  });
};

export const getLatestSuiSystemState = () => {
  return client.getLatestSuiSystemState();
};
