import { atom } from "nanostores";
import type { Stats } from "../types";
import { getCurrentSuiBalance, getLiSUIRatio } from "../client/lisuify";
import { log } from "../utils";
import { getValidatorAPY } from "../client/sui";

const defaulStats: Stats = {
  totalSuiStaking: BigInt(0),
  liSuiRatio: 1,
  validatorApy: 5.5,
};

export const statsAtom = atom<Stats>(defaulStats);

const initialStats = async () => {
  const totalSuiBalance = await getCurrentSuiBalance();
  const liSuiRatio = await getLiSUIRatio();
  const validatorApy = await getValidatorAPY();

  log("totalSuiBalance", totalSuiBalance);
  log("liSuiRatio", liSuiRatio);
  log("validatorApy", validatorApy);
  const averageApy =
    (validatorApy.apys.reduce((sum, a) => {
      return sum + a.apy;
    }, 0) /
      validatorApy.apys.length) *
    100;
  log("averageApy", averageApy);

  statsAtom.set({
    totalSuiStaking: totalSuiBalance,
    liSuiRatio: liSuiRatio,
    validatorApy: averageApy,
  });
};

initialStats();
