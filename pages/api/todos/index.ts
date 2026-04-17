import type { NextApiRequest, NextApiResponse } from 'next';
import { withApiHandler } from '@/lib/api-handler';
import type { Todo } from '@/types/todo';

async function handler(req: NextApiRequest, res: NextApiResponse) {
  const response = await fetch('https://jsonplaceholder.typicode.com/todos');

  if (!response.ok) {
    return res.status(response.status).json({
      success: false,
      data: null,
      error: `Failed to fetch todos: ${response.status}`,
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
