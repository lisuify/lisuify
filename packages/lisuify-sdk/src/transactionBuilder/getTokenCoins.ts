import {CoinStruct, SuiClient} from '@mysten/sui.js/client';

export const getTokenCoins = async ({
  originalLisuifyId,
  provider,
  owner,
}: {
  originalLisuifyId: string;
  provider: SuiClient;
  owner: string;
}) => {
  const result: CoinStruct[] = [];
  let cursor: string | null | undefined;
  for (;;) {
    const r = await provider.getCoins({
      owner,
      coinType: `${originalLisuifyId}::coin::COIN`,
      cursor,
    });
    result.push(...r.data);
    if (!r.hasNextPage) {
      return result;
    }
    cursor = r.nextCursor;
  }
};
