import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { network } from "../consts";

export const client = new SuiClient({
  url: getFullnodeUrl(network),
});
