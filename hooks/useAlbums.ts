import useSWR, { type KeyedMutator } from 'swr';
import type { Album } from '@/types/album';

interface UseAlbumsReturn {
  albums: Album[];
  isLoading: boolean;
  error: string | null;
  mutate: KeyedMutator<Album[]>;
}

export function useAlbums(): UseAlbumsReturn {
  const { data, error, isLoading, mutate } = useSWR<Album[]>(
    'https://jsonplaceholder.typicode.com/albums'
  );

  return {
    albums: data ?? [],
    isLoading,
    error: error ? (error as Error).message : null,
    mutate,
  };
}
