import type { NextApiRequest, NextApiResponse } from 'next';
import { withApiHandler } from '@/lib/api-handler';
import type { Todo } from '@/types/todo';

async function handler(req: NextApiRequest, res: NextApiResponse) {
  const page = Number(req.query.page ?? 1);
  const limit = Number(req.query.limit ?? 30);

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

  const response = await fetch('https://jsonplaceholder.typicode.com/todos');

  if (!response.ok) {
    return res.status(502).json({
      success: false,
      data: null,
      error: 'Failed to fetch todos from upstream service',
      meta: null,
    });
  }

  const allTodos: Todo[] = await response.json();
  const total = allTodos.length;
  const totalPages = Math.ceil(total / limit);
  const hasMore = page < totalPages;
  const start = (page - 1) * limit;
  const todos = allTodos.slice(start, start + limit);

  return res.status(200).json({
    success: true,
    data: todos,
    error: null,
    meta: { page, limit, total, totalPages, hasMore },
  });
}

export default withApiHandler(handler, { allowedMethods: ['GET'] });
