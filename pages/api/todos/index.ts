import type { NextApiRequest, NextApiResponse } from 'next';
import { withApiHandler, type ApiEnvelope } from '@/lib/api-handler';
import type { Todo } from '@/features/todos/types/todo';

export default withApiHandler(
  async (req: NextApiRequest, res: NextApiResponse<ApiEnvelope>) => {
    const pageParam = req.query.page;
    const limitParam = req.query.limit;

    const page = pageParam === undefined ? 1 : Number(pageParam);
    const limit = limitParam === undefined ? 20 : Number(limitParam);

    if (!Number.isInteger(page) || page < 1) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'page must be a positive integer',
        meta: null,
      });
    }

    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      return res.status(400).json({
        success: false,
        data: null,
        error: 'limit must be an integer between 1 and 100',
        meta: null,
      });
    }

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

    const todos: Todo[] = await response.json();
    const total = Number(response.headers.get('x-total-count') ?? 0);
    const totalPages = Math.ceil(total / limit);

    return res.status(200).json({
      success: true,
      data: { todos },
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
