import type { NextApiRequest, NextApiResponse } from 'next';
import handler from './index';

function createMockReqRes(method = 'GET', query: Record<string, string> = {}) {
  const req = { method, query } as unknown as NextApiRequest;
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const setHeader = jest.fn();
  const res = { status, json, setHeader } as unknown as NextApiResponse;
  return { req, res, status, json, setHeader };
}

const mockTodos = Array.from({ length: 50 }, (_, i) => ({
  userId: 1,
  id: i + 1,
  title: `todo ${i + 1}`,
  completed: i % 2 === 0,
}));

describe('GET /api/todos', () => {
  beforeEach(() => {
    jest.resetAllMocks();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve(mockTodos),
    });
  });

  it('returns paginated todos in standard envelope with default page and limit', async () => {
    const { req, res, status, json } = createMockReqRes();
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(200);
    const call = json.mock.calls[0][0];
    expect(call.success).toBe(true);
    expect(call.data).toHaveLength(30);
    expect(call.error).toBeNull();
    expect(call.meta).toEqual({ page: 1, limit: 30, total: 50, totalPages: 2, hasMore: true });
  });

  it('returns second page with correct pagination meta', async () => {
    const { req, res, status, json } = createMockReqRes('GET', { page: '2', limit: '30' });
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(200);
    const call = json.mock.calls[0][0];
    expect(call.data).toHaveLength(20);
    expect(call.meta).toEqual({ page: 2, limit: 30, total: 50, totalPages: 2, hasMore: false });
  });

  it('returns 502 envelope when upstream fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 503,
    });

    const { req, res, status, json } = createMockReqRes();
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(502);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'Failed to fetch todos from upstream service',
      meta: null,
    });
  });

  it('returns 500 envelope when fetch throws', async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error('Network error'));

    const { req, res, status, json } = createMockReqRes();
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(500);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'Internal server error',
      meta: null,
    });
  });

  it('returns 405 for unsupported methods', async () => {
    const { req, res, status, json, setHeader } = createMockReqRes('POST');
    await handler(req, res);

    expect(setHeader).toHaveBeenCalledWith('Allow', ['GET']);
    expect(status).toHaveBeenCalledWith(405);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'Method POST is not supported',
      meta: null,
    });
  });

  it('returns 400 when page is negative', async () => {
    const { req, res, status, json } = createMockReqRes('GET', { page: '-1' });
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'page must be a positive integer',
      meta: null,
    });
  });

  it('returns 400 when limit exceeds 100', async () => {
    const { req, res, status, json } = createMockReqRes('GET', { limit: '101' });
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'limit must be an integer between 1 and 100',
      meta: null,
    });
  });
});
