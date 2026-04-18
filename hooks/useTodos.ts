import useSWR, { type KeyedMutator } from 'swr';
import type { Todo } from '@/types/todo';

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<Todo[]>;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading, mutate } = useSWR<Todo[]>(
    '/api/todos'
  );

  return {
    todos: data ?? [],
    isLoading,
    error: error instanceof Error ? error.message : null,
    mutate,
  };
}
