import type { NextApiRequest, NextApiResponse } from 'next';
import prisma from '@/lib/prisma';
import { withApiHandler, type ApiEnvelope } from '@/lib/api-handler';
import { paginationSchema } from '@/lib/schemas/pagination';
import type { z } from 'zod';

export default withApiHandler(
  async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    const { page, limit } = req.query as unknown as z.infer<typeof paginationSchema>;

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

    const serializedProducts = products.map((p) => ({
      ...p,
      price: Number(p.price),
    }));

    return res.status(200).json({
      success: true,
      data: { products: serializedProducts },
      error: null,
      meta: {
        page,
        limit,
        total,
        totalPages,
        hasMore: page < totalPages,
      },
    });
  },
  { allowedMethods: ['GET'], querySchema: paginationSchema }
);
