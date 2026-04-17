import useSWR, { type KeyedMutator } from 'swr';
import type { Post } from '@/types/post';

interface UsePostsReturn {
  posts: Post[];
  isLoading: boolean;
  error: Error | undefined;
  mutate: KeyedMutator<Post[]>;
}

export function usePosts(): UsePostsReturn {
  const { data, error, isLoading, mutate } = useSWR<Post[]>(
    '/api/posts'
  );

  return {
    posts: data?.slice(0, 40) ?? [],
    isLoading,
    error,
    mutate,
  };
}
