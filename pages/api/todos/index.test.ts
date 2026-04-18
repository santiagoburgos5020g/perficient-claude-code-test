import type { NextApiRequest, NextApiResponse } from 'next';
import handler from './index';

const mockFetch = jest.fn();
global.fetch = mockFetch;

function createMocks(method: string) {
  const req = {
    method,
  } as NextApiRequest;

  const json = jest.fn();
  const setHeader = jest.fn();
  const status = jest.fn().mockReturnValue({ json });
  const res = { status, json, setHeader } as unknown as NextApiResponse;

  return { req, res, status, json, setHeader };
}

describe('/api/todos', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns todos in envelope on success', async () => {
    const mockTodos = [{ id: 1, userId: 1, title: 'Test', completed: false }];
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockTodos),
    });

    const { req, res, status, json } = createMocks('GET');
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      success: true,
      data: mockTodos,
      error: null,
      meta: null,
    });
  });

  it('returns 502 when upstream fails', async () => {
    mockFetch.mockResolvedValueOnce({ ok: false, status: 500 });

    const { req, res, status, json } = createMocks('GET');
    await handler(req, res);

    expect(status).toHaveBeenCalledWith(502);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'Failed to fetch todos from upstream',
      meta: null,
    });
  });

  it('returns 500 when fetch throws', async () => {
    mockFetch.mockRejectedValueOnce(new Error('Network error'));

    const { req, res, status, json } = createMocks('GET');
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
    const { req, res, status, json, setHeader } = createMocks('POST');
    await handler(req, res);

    expect(setHeader).toHaveBeenCalledWith('Allow', ['GET']);
    expect(status).toHaveBeenCalledWith(405);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'POST is not supported',
      meta: null,
    });
  });

  it('returns 405 for DELETE method', async () => {
    const { req, res, status, json, setHeader } = createMocks('DELETE');
    await handler(req, res);

    expect(setHeader).toHaveBeenCalledWith('Allow', ['GET']);
    expect(status).toHaveBeenCalledWith(405);
    expect(json).toHaveBeenCalledWith({
      success: false,
      data: null,
      error: 'DELETE is not supported',
      meta: null,
    });
  });
});
