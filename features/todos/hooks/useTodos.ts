import useSWR, { type KeyedMutator } from 'swr';
import type { Todo } from '@/features/todos/types/todo';
import type { ApiEnvelope } from '@/lib/api-handler';

type TodosEnvelope = ApiEnvelope<{ todos: Todo[] }>;

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<TodosEnvelope>;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading, mutate } = useSWR<TodosEnvelope>('/api/todos');

  return {
    todos: data?.data?.todos ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
    mutate,
  };
}
