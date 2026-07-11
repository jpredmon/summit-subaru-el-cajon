import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { handleInventoryRequest } from './_inventoryHandler.js';

// Minimal `res` double: records what the handler sets/calls, no real
// Vercel/Node HTTP runtime needed.
function createMockRes() {
  return {
    statusCode: 0,
    headers: {} as Record<string, string>,
    body: undefined as string | undefined,
    setHeader(name: string, value: string) {
      this.headers[name] = value;
    },
    end(chunk?: string) {
      this.body = chunk;
    },
  };
}

const ORIGINAL_ENV = { ...process.env };

describe('handleInventoryRequest', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    process.env = { ...ORIGINAL_ENV };
  });

  it('returns 500 with CORS header when VINCUE_API_KEY is missing', async () => {
    delete process.env.VINCUE_API_KEY;
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    const res = createMockRes();

    await handleInventoryRequest({} as never, res as never);

    expect(res.statusCode).toBe(500);
    expect(res.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(JSON.parse(res.body ?? '{}')).toEqual({
      error: 'Server misconfigured: VINCUE_API_KEY is not set',
    });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('relays upstream status and body verbatim with CORS header on success', async () => {
    process.env.VINCUE_API_KEY = 'test-key';
    const upstreamBody = '[{"vin":"12345"}]';
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      new Response(upstreamBody, { status: 200 }),
    );
    const res = createMockRes();

    await handleInventoryRequest({} as never, res as never);

    expect(res.statusCode).toBe(200);
    expect(res.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(res.body).toBe(upstreamBody);
    expect(globalThis.fetch).toHaveBeenCalledWith(
      'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
      { headers: { 'x-api-key': 'test-key' } },
    );
  });

  it('returns 502 with CORS header when upstream fetch throws', async () => {
    process.env.VINCUE_API_KEY = 'test-key';
    vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('network down'));
    const res = createMockRes();

    await handleInventoryRequest({} as never, res as never);

    expect(res.statusCode).toBe(502);
    expect(res.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(JSON.parse(res.body ?? '{}')).toEqual({
      error: 'Failed to reach upstream inventory API',
    });
  });
});
