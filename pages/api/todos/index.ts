import type { NextApiRequest, NextApiResponse } from 'next';
import type { Todo } from '@/types/todo';
import { withApiHandler } from '@/lib/with-api-handler';

async function handler(req: NextApiRequest, res: NextApiResponse) {
  const response = await fetch(process.env.TODOS_API_URL!);
  if (!response.ok) {
    return res.status(502).json({
      success: false,
      data: null,
      error: 'Failed to fetch todos from upstream',
      meta: null,
    });
  }
  const todos: Todo[] = await response.json();
  return res.status(200).json({
    success: true,
    data: todos,
    error: null,
    meta: null,
  });
}

export default withApiHandler(handler, { allowedMethods: ['GET'] });
