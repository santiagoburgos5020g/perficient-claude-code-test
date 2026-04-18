import useSWR from 'swr';
import type { Todo } from '@/features/todos/types/todo';
import type { ApiEnvelope } from '@/lib/api-handler';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading } = useSWR<ApiEnvelope<{ todos: Todo[] }>>('/api/todos');

  return {
    todos: data?.data?.todos ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
  };
}
