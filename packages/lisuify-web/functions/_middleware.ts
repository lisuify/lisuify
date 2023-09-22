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
  const response = await context.next();
  response.headers.set("Cache-Control", "public, max-age=600");
  return response;
};
