import useSWR, { type KeyedMutator } from 'swr';
import type { Todo } from '@/types/todo';
import type { ApiResponse } from '@/lib/with-api-handler';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<ApiResponse<Todo[]>>;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading, mutate } = useSWR<ApiResponse<Todo[]>>(
    '/api/todos'
  );

  return {
    todos: data?.success ? data.data : [],
    isLoading,
    error: error instanceof Error ? error.message : null,
    mutate,
  };
}
