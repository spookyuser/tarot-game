const AI_GATEWAY_URL =
  "https://gateway.ai.cloudflare.com/v1/00b4144a8738939d6f258250f7c5f063/tarot/compat/chat/completions";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: CORS_HEADERS,
      });
    }

    const response = await fetch(AI_GATEWAY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.CLOUDFLARE_BEARER_TOKEN}`,
      },
      body: request.body,
    });

    const newResponse = new Response(response.body, response);
    for (const [key, value] of Object.entries(CORS_HEADERS)) {
      newResponse.headers.set(key, value);
    }
    return newResponse;
  },
};
