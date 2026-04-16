import useSWR from 'swr';
import type { User } from '@/features/users/types/user';

const fetcher = (url: string) =>
  fetch(url).then((res) => {
    if (!res.ok) throw new Error(`Failed to fetch users (${res.status})`);
    return res.json();
  });

export function useUsers() {
  const { data, error, isLoading, mutate } = useSWR<User[]>(
    'https://jsonplaceholder.typicode.com/users',
    fetcher
  );

  return {
    users: data ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
    mutate,
  };
}
