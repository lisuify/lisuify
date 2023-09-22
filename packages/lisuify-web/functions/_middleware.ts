import { type PagesFunction } from "@cloudflare/workers-types";

export const onRequestOptions: PagesFunction = async () => {
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Max-Age": "86400",
    },
  });
};

export const onRequest: PagesFunction = async (context) => {
  console.log("context", JSON.stringify(context));
  const response = await context.next();
  response.headers.set("Access-Control-Max-Age", "86400");
  return response;
};
