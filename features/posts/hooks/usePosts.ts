import useSWR, { type KeyedMutator } from 'swr';
import type { Post } from '@/features/posts/types/post';

interface UsePostsReturn {
  posts: Post[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<Post[]>;
}

export function usePosts(): UsePostsReturn {
  const { data, error, isLoading, mutate } = useSWR<Post[]>(
    'https://jsonplaceholder.typicode.com/posts'
  );

  return {
    posts: data?.slice(0, 40) ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
    mutate,
  };
}
