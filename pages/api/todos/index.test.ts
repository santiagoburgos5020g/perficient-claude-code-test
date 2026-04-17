import type { NextApiRequest, NextApiResponse } from 'next';
import handler from './index';

function createMockReqRes(method = 'GET') {
  const req = { method } as NextApiRequest;
  const json = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const setHeader = jest.fn();
  const res = { status, json, setHeader } as unknown as NextApiResponse;
  return { req, res, status, json, setHeader };
}

const mockTodos = [
  { userId: 1, id: 1, title: 'todo 1', completed: false },
  { userId: 1, id: 2, title: 'todo 2', completed: true },
];

describe('GET /api/todos', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('returns todos in standard envelope on success', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve(mockTodos),
    });

    const { req, res, status, json } = createMockReqRes();
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: true,
      data: mockTodos,
      error: null,
      meta: null,
    });
  });

  it('returns error envelope when upstream fails', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 502,
    });

    const { req, res, status, json } = createMockReqRes();
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(502);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'Failed to fetch todos: 502',
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
});
