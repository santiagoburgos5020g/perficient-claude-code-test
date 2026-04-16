import useSWR, { type KeyedMutator } from 'swr';
import type { User } from '@/features/users/types/user';

interface UseUsersReturn {
  users: User[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<User[]>;
}

export function useUsers(): UseUsersReturn {
  const { data, error, isLoading, mutate } = useSWR<User[]>(
    'https://jsonplaceholder.typicode.com/users'
  );

  return {
    users: data ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
    mutate,
  };
}
