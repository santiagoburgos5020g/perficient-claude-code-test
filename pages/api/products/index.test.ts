import { createMocks } from 'node-mocks-http';
import type { NextApiRequest, NextApiResponse } from 'next';
import handler from './index';

jest.mock('@/lib/prisma', () => ({
  __esModule: true,
  default: {
    product: {
      findMany: jest.fn(),
      count: jest.fn(),
    },
  },
}));

import prisma from '@/lib/prisma';

const mockFindMany = prisma.product.findMany as jest.Mock;
const mockCount = prisma.product.count as jest.Mock;

const mockProduct = {
  id: 1,
  name: 'Widget',
  description: 'A widget',
  price: { toNumber: () => 9.99, toString: () => '9.99' },
  image: '/widget.jpg',
};

function createGetMocks(query: Record<string, string> = {}) {
  return createMocks<NextApiRequest, NextApiResponse>({
    method: 'GET',
    query,
  });
}

describe('/api/products', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('returns 200 with correct envelope and serialized products', async () => {
    mockFindMany.mockResolvedValue([mockProduct]);
    mockCount.mockResolvedValue(1);
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(true);
    expect(body.data.products).toEqual([{
      id: 1,
      name: 'Widget',
      description: 'A widget',
      price: 9.99,
      image: '/widget.jpg',
    }]);
    expect(body.error).toBeNull();
    expect(body.meta).toEqual({
      page: 1,
      limit: 30,
      total: 1,
      totalPages: 1,
      hasMore: false,
    });
  });

  it('returns 200 with empty array when no products', async () => {
    mockFindMany.mockResolvedValue([]);
    mockCount.mockResolvedValue(0);
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(true);
    expect(body.data.products).toEqual([]);
    expect(body.meta.total).toBe(0);
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

  it('paginates with custom page and limit', async () => {
    mockFindMany.mockResolvedValue([mockProduct]);
    mockCount.mockResolvedValue(100);
    const { req, res } = createGetMocks({ page: '2', limit: '10' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.meta.page).toBe(2);
    expect(body.meta.limit).toBe(10);
    expect(body.meta.total).toBe(100);
    expect(body.meta.totalPages).toBe(10);
    expect(body.meta.hasMore).toBe(true);

    expect(mockFindMany).toHaveBeenCalledWith(
      expect.objectContaining({ skip: 10, take: 10 })
    );
  });

  it('handles boundary page=1 limit=100', async () => {
    mockFindMany.mockResolvedValue([]);
    mockCount.mockResolvedValue(0);
    const { req, res } = createGetMocks({ page: '1', limit: '100' });

    await handler(req, res);

    expect(res._getStatusCode()).toBe(200);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(true);
    expect(body.data.products).toEqual([]);
  });

  it('returns 500 when Prisma throws', async () => {
    mockFindMany.mockRejectedValue(new Error('DB error'));
    mockCount.mockResolvedValue(0);
    const { req, res } = createGetMocks();

    await handler(req, res);

    expect(res._getStatusCode()).toBe(500);
    const body = JSON.parse(res._getData());
    expect(body.success).toBe(false);
    expect(body.error).toBe('Internal server error');
  });
});
