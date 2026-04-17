import useSWR, { type KeyedMutator } from 'swr';
import type { Todo } from '@/types/todo';
import type { ApiEnvelope } from '@/lib/api-handler';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: Error | undefined;
  mutate: KeyedMutator<ApiEnvelope<Todo[]>>;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading, mutate } = useSWR<ApiEnvelope<Todo[]>>(
    '/api/todos'
  );

  return {
    todos: data?.data ?? [],
    isLoading,
    error,
    mutate,
  };
}
