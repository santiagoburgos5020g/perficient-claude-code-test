import useSWR from 'swr';
import type { Todo } from '@/features/todos/types/todo';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading } = useSWR<Todo[]>(
    'https://jsonplaceholder.typicode.com/todos'
  );

  return {
    todos: data ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
  };
}
