import { persistentAtom } from "@nanostores/persistent";
import type { SuiSystemStateSummaryData } from "../types";
import { getLatestSuiSystemState } from "../client/rpc";
import { log } from "../utils";

export const suiSystemStateAtom =
  persistentAtom<SuiSystemStateSummaryData | null>("suiSystemStateAtom", null, {
    encode: JSON.stringify,
    decode: JSON.parse,
  });

const suiSystemState = suiSystemStateAtom.get();
log("suiSystemState", suiSystemState);

if (suiSystemState) {
  if (
    Number(suiSystemState.epochStartTimestampMs) +
      Number(suiSystemState.epochDurationMs) <
    new Date().getTime()
  ) {
    getLatestSuiSystemState().then((latestSuiSystemState) => {
      suiSystemStateAtom.set(latestSuiSystemState);
    });
  }
} else {
  getLatestSuiSystemState().then((latestSuiSystemState) => {
    suiSystemStateAtom.set(latestSuiSystemState);
  });
}
