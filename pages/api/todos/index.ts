import type { NextApiRequest, NextApiResponse } from 'next';
import type { Todo } from '@/types/todo';

interface TodosApiError {
  error: string;
  message: string;
}

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<Todo[] | TodosApiError>
) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', ['GET']);
    return res.status(405).json({ error: 'Method not allowed', message: `${req.method} is not supported` });
  }

  try {
    const response = await fetch('https://jsonplaceholder.typicode.com/todos');

    if (!response.ok) {
      return res.status(response.status).json({
        error: 'Upstream error',
        message: `Failed to fetch todos: ${response.status}`,
      });
    }

    const todos: Todo[] = await response.json();
    return res.status(200).json(todos);
  } catch {
    return res.status(500).json({
      error: 'Failed to fetch todos',
      message: 'Internal server error',
    });
  }
}
