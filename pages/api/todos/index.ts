import type { NextApiRequest, NextApiResponse } from 'next';
import { z } from 'zod';
import { withApiHandler, type ApiEnvelope } from '@/lib/api-handler';
import { todoSchema } from '@/features/todos/types/todo';
import { paginationSchema } from '@/lib/schemas/pagination';

export default withApiHandler(
  async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    const parsed = paginationSchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({
        success: false,
        data: null,
        error: parsed.error.issues.map((i) => i.message).join('; '),
        meta: null,
      });
    }

    const { page, limit } = parsed.data;

    const baseUrl = process.env.TODOS_API_URL;
    if (!baseUrl) {
      return res.status(500).json({
        success: false,
        data: null,
        error: 'TODOS_API_URL environment variable is not configured',
        meta: null,
      });
    }

    const start = (page - 1) * limit;
    const response = await fetch(`${baseUrl}?_start=${start}&_limit=${limit}`);

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
  { allowedMethods: ['GET'] }
);
