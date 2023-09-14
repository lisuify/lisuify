import { atom } from "nanostores";
import type { Stats } from "../types";
import { getCurrentSuiBalance, getLiSUIRatio } from "../client/lisuify";
import { log } from "../utils";

const defaulStats: Stats = {
  totalSuiStaking: BigInt(0),
  liSuiRatio: 1,
};

export const statsAtom = atom<Stats>(defaulStats);

const initialStats = async () => {
  const totalSuiBalance = await getCurrentSuiBalance();
  const liSuiRatio = await getLiSUIRatio();

  log("totalSuiBalance", totalSuiBalance);
  log("liSuiRatio", liSuiRatio);

  statsAtom.set({
    totalSuiStaking: totalSuiBalance,
    liSuiRatio: liSuiRatio,
  });
};

initialStats();
