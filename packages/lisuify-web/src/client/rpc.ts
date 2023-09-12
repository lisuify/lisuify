import { client } from "./client";

export const getWalletBalance = (address: string) => {
  return client.getBalance({
    owner: address,
  });
};

export const getLiSUIBalance = (address: string) => {
}

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
