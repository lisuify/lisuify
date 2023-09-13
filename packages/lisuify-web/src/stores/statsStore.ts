import { atom } from "nanostores";
import type { Stats } from "../types";
import { getLiSUIRatio } from "../client/lisuify";

const defaulStats: Stats = {
  liSuiRatio: BigInt(0),
};

export const statsAtom = atom<Stats>(defaulStats);

const initialStats = async () => {
  const liSuiRatio = await getLiSUIRatio();

  statsAtom.set({
    liSuiRatio: liSuiRatio,
  });
};

initialStats();
