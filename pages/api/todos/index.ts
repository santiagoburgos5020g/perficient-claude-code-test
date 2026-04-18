import type { NextApiRequest, NextApiResponse } from 'next';
import { z } from 'zod';
import { withApiHandler, type ApiEnvelope } from '@/lib/api-handler';
import { todoSchema } from '@/features/todos/types/todo';
import { paginationSchema } from '@/lib/schemas/pagination';
import { env } from '@/lib/env';

export default withApiHandler(
  async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    const { page, limit } = req.query as unknown as z.infer<typeof paginationSchema>;

    const start = (page - 1) * limit;
    const response = await fetch(`${env.TODOS_API_URL}?_start=${start}&_limit=${limit}`);

    if (!response.ok) {
      return res.status(response.status).json({
        success: false,
        data: null,
        error: `Upstream error: JSONPlaceholder responded with ${response.status}`,
        meta: null,
      });
    }

    const rawData = await response.json();
    const todosResult = z.array(todoSchema).safeParse(rawData);

    if (!todosResult.success) {
      return res.status(502).json({
        success: false,
        data: null,
        error: 'Upstream response did not match expected schema',
        meta: null,
      });
    }

    const total = Number(response.headers.get('x-total-count') ?? 0);
    const totalPages = Math.ceil(total / limit);

    return res.status(200).json({
      success: true,
      data: { todos: todosResult.data },
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
