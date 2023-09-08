import { network } from "./consts";

export const log = (message?: any, ...optionalParams: any[]) => {
  if (network !== "devnet") return;
  console.log(message, ...optionalParams);
};

export const shortAddress = (address: string) => {
  return address.slice(0, 6) + "..." + address.slice(62, 66);
};

export function round(num: number, decimal: number = 3): number {
  const div = Math.pow(10, decimal);
  return Math.round(num * div) / div;
}

const suiDecimal = 10 ** 9;

export const suiToString = (amount: bigint | number) => {
  return round(Number(amount) / suiDecimal).toString();
};

export const blockExplorerLink = (digest: string) => {
  return `https://suiexplorer.com/txblock/${digest}?network=${network}`;
};

export const objectExplorerLink = (objectId: string) => {
  return `https://suiexplorer.com/object/${objectId}?network=${network}`;
};
