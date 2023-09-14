import { SUI_DECIMALS } from "@mysten/sui.js/utils";
import { network } from "./consts";

export const log = (message?: any, ...optionalParams: any[]) => {
  if (network !== "devnet") return;
  console.log(message, ...optionalParams);
};

export const shortAddress = (address: string) => {
  return address.slice(0, 6) + "..." + address.slice(62, 66);
};

export function round(num: number, decimal: number = 4): number {
  const div = Math.pow(10, decimal);
  return Math.round(num * div) / div;
}

export function floor(num: number, decimal: number = 4): number {
  const div = Math.pow(10, decimal);
  return Math.floor(num * div) / div;
}

const suiDecimalDivisor = 10 ** SUI_DECIMALS;

export const suiToNumber = (amount: bigint | number) => {
  return Number(amount) / suiDecimalDivisor;
};

export const suiToString = (amount: bigint | number) => {
  return floor(Number(amount) / suiDecimalDivisor).toString();
};

export const blockExplorerLink = (digest: string) => {
  return `https://suiexplorer.com/txblock/${digest}?network=${network}`;
};

export const objectExplorerLink = (objectId: string) => {
  return `https://suiexplorer.com/object/${objectId}?network=${network}`;
};
