import { atom } from "nanostores";
import type { Stats } from "../types";
import { getCurrentSuiBalance, getLiSUIRatio } from "../client/lisuify";

const defaulStats: Stats = {
  totalSuiStaking: BigInt(0),
  liSuiRatio: BigInt(0),
};

export const statsAtom = atom<Stats>(defaulStats);

const initialStats = async () => {
  const totalSuiBalance = await getCurrentSuiBalance();
  const liSuiRatio = await getLiSUIRatio();

  statsAtom.set({
    totalSuiStaking: totalSuiBalance,
    liSuiRatio: liSuiRatio,
  });
};

initialStats();
