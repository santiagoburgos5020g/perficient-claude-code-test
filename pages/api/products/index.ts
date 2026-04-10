import type { NextApiRequest, NextApiResponse } from 'next';
import { PrismaClient } from '@prisma/client';
import type { ProductsApiResponse, ProductsApiError } from '@/features/products/types/product';

const prisma = new PrismaClient();

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ProductsApiResponse | ProductsApiError>
) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', ['GET']);
    return res.status(405).json({ error: 'Method not allowed', message: `${req.method} is not supported` });
  }

  const pageParam = req.query.page;
  const limitParam = req.query.limit;

  const page = pageParam === undefined ? 1 : Number(pageParam);
  const limit = limitParam === undefined ? 30 : Number(limitParam);

  if (!Number.isInteger(page) || page < 1) {
    return res.status(400).json({
      error: 'Invalid parameters',
      message: 'page must be a positive integer',
    });
  }

  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    return res.status(400).json({
      error: 'Invalid parameters',
      message: 'limit must be an integer between 1 and 100',
    });
  }

  try {
    const [products, total] = await Promise.all([
      prisma.product.findMany({
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { id: 'asc' },
        select: {
          id: true,
          name: true,
          description: true,
          price: true,
          image: true,
        },
      }),
      prisma.product.count(),
    ]);

    const totalPages = Math.ceil(total / limit);
    const hasMore = page < totalPages;

    return res.status(200).json({
      products,
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasMore,
      },
    });
  } catch (error) {
    console.error('Failed to fetch products:', error);
    return res.status(500).json({
      error: 'Failed to fetch products',
      message: 'Internal server error',
    });
  }
}
