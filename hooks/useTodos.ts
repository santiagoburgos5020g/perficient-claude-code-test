import useSWR, { type KeyedMutator } from 'swr';
import type { Todo } from '@/types/todo';
import type { ApiEnvelope } from '@/lib/api-handler';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<ApiEnvelope<Todo[]>>;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading, mutate } = useSWR<ApiEnvelope<Todo[]>>(
    '/api/todos'
  );

  return {
    todos: (data?.data as Todo[]) ?? [],
    isLoading,
    error: error instanceof Error ? error.message : (data?.error ?? null),
    mutate,
  };
}
