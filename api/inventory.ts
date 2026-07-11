import type { IncomingMessage, ServerResponse } from 'node:http';

import { handleInventoryRequest } from './_inventoryHandler.js';

// Vercel Node serverless function entry point — zero-config, auto-detected
// from this file's location under /api.
export default function handler(req: IncomingMessage, res: ServerResponse) {
  return handleInventoryRequest(req, res);
}
