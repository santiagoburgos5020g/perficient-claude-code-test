import useSWR from 'swr';
import type { Todo } from '@/features/todos/types/todo';

interface TodosApiResponse {
  todos: Todo[];
}

interface UseTodosReturn {
  todos: Todo[];
  isLoading: boolean;
  error: string | null;
}

export function useTodos(): UseTodosReturn {
  const { data, error, isLoading } = useSWR<TodosApiResponse>('/api/todos');

  return {
    todos: data?.todos ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
  };
}
