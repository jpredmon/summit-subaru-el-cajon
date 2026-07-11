import type { IncomingMessage, ServerResponse } from 'node:http';

const DEALER_ID = 54222;
const INVENTORY_URL = `https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=${DEALER_ID}`;

// This proxy is called cross-origin by this app's own web build (unlike the
// reference app's same-origin deployment), so every response path sets an
// open CORS header. The inventory data behind it is public read-only dealer
// inventory — no auth, no user data — so an open origin policy matches the
// trust level of the underlying endpoint once the key is server-side.
const CORS_HEADER = 'Access-Control-Allow-Origin';
const CORS_VALUE = '*';

export async function handleInventoryRequest(
  _req: IncomingMessage,
  res: ServerResponse,
): Promise<void> {
  const apiKey = process.env.VINCUE_API_KEY;

  if (!apiKey) {
    res.statusCode = 500;
    res.setHeader(CORS_HEADER, CORS_VALUE);
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Server misconfigured: VINCUE_API_KEY is not set' }));
    return;
  }

  try {
    const upstream = await fetch(INVENTORY_URL, {
      headers: { 'x-api-key': apiKey },
    });
    const body = await upstream.text();
    res.statusCode = upstream.status;
    res.setHeader(CORS_HEADER, CORS_VALUE);
    res.setHeader('Content-Type', 'application/json');
    res.end(body);
  } catch {
    res.statusCode = 502;
    res.setHeader(CORS_HEADER, CORS_VALUE);
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ error: 'Failed to reach upstream inventory API' }));
  }
}
