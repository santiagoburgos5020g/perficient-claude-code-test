import { createMocks } from 'node-mocks-http';
import type { NextApiRequest, NextApiResponse } from 'next';
import handler from './index';

const originalFetch = global.fetch;
const originalEnv = process.env.TODOS_API_URL;

function mockFetchSuccess(todos: unknown[], total: number) {
  global.fetch = jest.fn().mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => todos,
    headers: new Map([['x-total-count', String(total)]]) as unknown as Headers,
  }) as jest.Mock;
}

function mockFetchHeaders(todos: unknown[], total: number) {
  const headers = { get: (key: string) => key === 'x-total-count' ? String(total) : null };
  global.fetch = jest.fn().mockResolvedValue({
    ok: true,
    status: 200,
    json: async () => todos,
    headers,
  }) as jest.Mock;
}

function createGetMocks(query: Record<string, string> = {}) {
  return createMocks<NextApiRequest, NextApiResponse>({
    method: 'GET',
    query,
  });
}

const validTodo = { userId: 1, id: 1, title: 'Test', completed: false };

describe('/api/todos', () => {
  beforeEach(() => {
    process.env.TODOS_API_URL = 'https://jsonplaceholder.typicode.com/todos';
  });

  afterEach(() => {
    global.fetch = originalFetch;
    process.env.TODOS_API_URL = originalEnv;
  });

  it('returns 200 with correct envelope on valid GET', async () => {
    mockFetchHeaders([validTodo], 1);
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(true);
    expect(body.data.todos).toEqual([validTodo]);
    expect(body.error).toBeNull();
    expect(body.meta).toEqual({
      page: 1,
      limit: 30,
      total: 1,
      totalPages: 1,
      hasMore: false,
    });
  });

  it('returns 400 for invalid page parameter', async () => {
    const { req, res } = createGetMocks({ page: '-1' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(400);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
    expect(body.error).toBeTruthy();
  });

  it('returns 400 for non-numeric page', async () => {
    const { req, res } = createGetMocks({ page: 'abc' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(400);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
  });

  it('returns 400 for limit exceeding maximum', async () => {
    const { req, res } = createGetMocks({ limit: '101' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(400);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
  });

  it('returns 400 for limit of zero', async () => {
    const { req, res } = createGetMocks({ limit: '0' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(400);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
  });

  it('returns 405 for POST method', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: 'POST',
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(405);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
    expect(body.error).toContain('Method not allowed');
    expect(res.getHeader('Allow')).toEqual(['GET']);
  });

  it('returns 405 for PUT method', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: 'PUT',
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(405);
  });

  it('returns 405 for DELETE method', async () => {
    const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
      method: 'DELETE',
    });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(405);
  });

  it('returns upstream status on upstream error', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 503,
    }) as jest.Mock;
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(503);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
    expect(body.error).toContain('503');
  });

  it('returns 502 when upstream returns malformed data', async () => {
    const headers = { get: () => '1' };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => [{ bad: 'data' }],
      headers,
    }) as jest.Mock;
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(502);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
    expect(body.error).toContain('schema');
  });

  it('paginates with custom page and limit', async () => {
    mockFetchHeaders([validTodo], 100);
    const { req, res } = createGetMocks({ page: '2', limit: '10' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.meta.page).toBe(2);
    expect(body.meta.limit).toBe(10);
    expect(body.meta.total).toBe(100);
    expect(body.meta.totalPages).toBe(10);
    expect(body.meta.hasMore).toBe(true);

    const fetchCall = (global.fetch as jest.Mock).mock.calls[0][0];
    expect(fetchCall).toContain('_start=10');
    expect(fetchCall).toContain('_limit=10');
  });

  it('handles edge case page=1 limit=100', async () => {
    mockFetchHeaders([], 0);
    const { req, res } = createGetMocks({ page: '1', limit: '100' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(true);
    expect(body.data.todos).toEqual([]);
  });
});
